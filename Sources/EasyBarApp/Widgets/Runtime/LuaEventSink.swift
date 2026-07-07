import EasyBarShared
import Foundation

/// Serializes event delivery into the Lua runtime off the EventHub hot path.
///
/// Sendability is guarded by `LockedState`; queue contents and drain ownership
/// are mutated only while holding the lock, and actual runtime writes happen
/// from one drain task at a time.
final class LuaEventSink: @unchecked Sendable {
  private static let reliableQueueLimit = 128
  private static let coalescingQueueLimit = 128

  private struct State {
    var reliablePayloads: [EasyBarEventPayload] = []
    var coalescedPayloads: [String: EasyBarEventPayload] = [:]
    var coalescedPayloadOrder: [String] = []
    var draining = false

    var isEmpty: Bool {
      reliablePayloads.isEmpty && coalescedPayloads.isEmpty
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
  /// if Lua falls behind far enough to exceed the hard queue bound.
  private func enqueueReliable(_ payload: EasyBarEventPayload, state: inout State) {
    if state.reliablePayloads.count >= Self.reliableQueueLimit {
      let dropped = state.reliablePayloads.removeFirst()
      logger.warn(
        "dropping queued lua event due to backpressure",
        .field("name", dropped.eventName)
      )
    }

    state.reliablePayloads.append(payload)
  }

  /// Stores the newest coalescing payload for its target key.
  private func enqueueCoalescing(_ payload: EasyBarEventPayload, state: inout State) {
    let key = coalescingKey(for: payload)

    if state.coalescedPayloads[key] == nil {
      if state.coalescedPayloadOrder.count >= Self.coalescingQueueLimit,
        let droppedKey = state.coalescedPayloadOrder.first
      {
        state.coalescedPayloadOrder.removeFirst()
        if let dropped = state.coalescedPayloads.removeValue(forKey: droppedKey) {
          logger.warn(
            "dropping coalesced lua event due to backpressure",
            .field("name", dropped.eventName)
          )
        }
      }

      state.coalescedPayloadOrder.append(key)
    }

    state.coalescedPayloads[key] = payload
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

  /// Takes one stable batch of pending payloads.
  private func takeNextBatch() -> [EasyBarEventPayload] {
    state.withLock { state -> [EasyBarEventPayload] in
      guard !state.isEmpty else {
        state.draining = false
        return []
      }

      let reliablePayloads = state.reliablePayloads
      let coalescedPayloads = state.coalescedPayloadOrder.compactMap { key in
        state.coalescedPayloads[key]
      }

      state.reliablePayloads.removeAll(keepingCapacity: true)
      state.coalescedPayloads.removeAll(keepingCapacity: true)
      state.coalescedPayloadOrder.removeAll(keepingCapacity: true)

      return reliablePayloads + coalescedPayloads
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
