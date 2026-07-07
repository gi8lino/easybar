import EasyBarShared
import Foundation

/// Serializes ordered event delivery into the Lua runtime off the EventHub hot path.
///
/// Sendability is guarded by `LockedState`; queue contents and drain ownership
/// are mutated only while holding the lock, and actual runtime writes happen
/// from one drain task at a time.
final class LuaEventSink: @unchecked Sendable {
  private static let reliableQueueLimit = 128
  private static let coalescingQueueLimit = 128

  private struct QueueEntry {
    let coalescingKey: String?
    var payload: EasyBarEventPayload
  }

  private struct State {
    var payloadQueue: [QueueEntry] = []
    var coalescedPayloadIndices: [String: Int] = [:]
    var reliablePayloadCount = 0
    var coalescingPayloadCount = 0
    var draining = false

    var isEmpty: Bool {
      payloadQueue.isEmpty
    }
  }

  private let runtime: LuaRuntime
  private let logger: ProcessLogger
  private let state = LockedState(State())

  /// Creates one Lua event sink.
  init(
    runtime: LuaRuntime,
    logger: ProcessLogger
  ) {
    self.runtime = runtime
    self.logger = logger
  }

  /// Enqueues one event payload for Lua delivery.
  func enqueue(_ payload: EasyBarEventPayload) {
    let shouldStartDraining = state.withLock { state -> Bool in
      switch EventDeliveryPolicy.forEventName(payload.eventName) {
      case .reliable:
        enqueueReliable(payload, state: &state)
      case .coalescing:
        enqueueCoalescing(payload, state: &state)
      }

      guard !state.draining else { return false }
      state.draining = true
      return true
    }

    guard shouldStartDraining else { return }

    Task { [weak self] in
      await self?.drainLoop()
    }
  }

  /// Appends a reliable payload, dropping oldest queued reliable payloads first
  /// if Lua falls behind far enough to exceed the hard reliable queue bound.
  private func enqueueReliable(_ payload: EasyBarEventPayload, state: inout State) {
    if state.reliablePayloadCount >= Self.reliableQueueLimit {
      guard let droppedIndex = state.payloadQueue.firstIndex(where: { $0.coalescingKey == nil })
      else { return }

      let dropped = removeQueuedPayload(at: droppedIndex, state: &state)
      logger.warn(
        "dropping queued lua event due to backpressure",
        .field("name", dropped.payload.eventName)
      )
    }

    state.payloadQueue.append(
      QueueEntry(
        coalescingKey: nil,
        payload: payload
      )
    )
    state.reliablePayloadCount += 1
  }

  /// Stores the newest coalescing payload for its target key at the newest
  /// queue position. This preserves enqueue order across reliable and
  /// coalescing events without letting high-frequency events grow unbounded.
  private func enqueueCoalescing(_ payload: EasyBarEventPayload, state: inout State) {
    let key = coalescingKey(for: payload)

    if let existingIndex = state.coalescedPayloadIndices[key] {
      _ = removeQueuedPayload(at: existingIndex, state: &state)
    } else if state.coalescingPayloadCount >= Self.coalescingQueueLimit {
      guard let droppedIndex = state.payloadQueue.firstIndex(where: { $0.coalescingKey != nil })
      else { return }

      let dropped = removeQueuedPayload(at: droppedIndex, state: &state)
      logger.warn(
        "dropping coalesced lua event due to backpressure",
        .field("name", dropped.payload.eventName)
      )
    }

    state.coalescedPayloadIndices[key] = state.payloadQueue.count
    state.payloadQueue.append(
      QueueEntry(
        coalescingKey: key,
        payload: payload
      )
    )
    state.coalescingPayloadCount += 1
  }

  /// Removes one queued payload and keeps coalescing indices/counts consistent.
  private func removeQueuedPayload(at index: Int, state: inout State) -> QueueEntry {
    let removed = state.payloadQueue.remove(at: index)

    if let key = removed.coalescingKey {
      state.coalescedPayloadIndices.removeValue(forKey: key)
      state.coalescingPayloadCount -= 1
    } else {
      state.reliablePayloadCount -= 1
    }

    let shiftedIndices = state.coalescedPayloadIndices.compactMap { entry -> (String, Int)? in
      let key = entry.key
      let queuedIndex = entry.value
      return queuedIndex > index ? (key, queuedIndex - 1) : nil
    }

    for (key, shiftedIndex) in shiftedIndices {
      state.coalescedPayloadIndices[key] = shiftedIndex
    }

    return removed
  }

  /// Drains queued payloads until the queue becomes empty.
  private func drainLoop() async {
    while true {
      let batch = takeNextBatch()
      guard !batch.isEmpty else { return }

      for payload in batch {
        await send(payload)
      }
    }
  }

  /// Takes one stable ordered batch of pending payloads.
  private func takeNextBatch() -> [EasyBarEventPayload] {
    state.withLock { state -> [EasyBarEventPayload] in
      guard !state.isEmpty else {
        state.draining = false
        return []
      }

      let payloads = state.payloadQueue.map(\.payload)

      state.payloadQueue.removeAll(keepingCapacity: true)
      state.coalescedPayloadIndices.removeAll(keepingCapacity: true)
      state.reliablePayloadCount = 0
      state.coalescingPayloadCount = 0

      return payloads
    }
  }

  /// Encodes and sends one payload to the Lua runtime.
  private func send(_ payload: EasyBarEventPayload) async {
    guard let encoded = Self.encodedPayload(payload) else {
      logger.error(
        "failed to encode lua event payload",
        .field("name", payload.eventName)
      )
      return
    }

    logger.trace("sent event to lua socket", .field("bytes", encoded.utf8.count))
    await runtime.send(encoded)
  }

  /// Returns the encoded Lua payload string.
  private static func encodedPayload(_ payload: EasyBarEventPayload) -> String? {
    return encodeJSON(payload.luaPayload)
  }

  /// Encodes one event payload as JSON for the Lua runtime.
  private static func encodeJSON(_ payload: LuaEventPayload) -> String? {
    guard
      let data = try? JSONEncoder().encode(payload),
      let string = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return string
  }

  /// Returns the coalescing key for one payload.
  private func coalescingKey(for payload: EasyBarEventPayload) -> String {
    [
      payload.eventName,
      payload.widgetID ?? "",
      payload.targetWidgetID ?? "",
    ].joined(separator: "\u{1f}")
  }
}
