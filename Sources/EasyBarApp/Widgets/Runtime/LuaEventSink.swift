import EasyBarShared
import Foundation

/// Serializes event delivery into the Lua runtime off the EventHub hot path.
///
/// Sendability is guarded by `LockedState`; queue contents and drain ownership
/// are mutated only while holding the lock, and actual runtime writes happen
/// from one drain task at a time. Must-deliver events are never evicted. State
/// events coalesce by event and widget target.
final class LuaEventSink: @unchecked Sendable {
  private static let mustDeliverBacklogWarningThreshold = 128
  private static let coalescingQueueLimit = 128

  private struct QueueEntry {
    let coalescingKey: String?
    var payload: EasyBarEventPayload
  }

  private enum QueuePressure {
    case mustDeliverBacklog(count: Int)
    case coalesced(eventName: String)
  }

  private struct EnqueueOutcome {
    let shouldStartDraining: Bool
    let pressure: QueuePressure?
  }

  private struct State {
    var payloadQueue: [QueueEntry] = []
    var coalescedPayloadIndices: [String: Int] = [:]
    var mustDeliverPayloadCount = 0
    var coalescingPayloadCount = 0
    var nextMustDeliverWarningCount = LuaEventSink.mustDeliverBacklogWarningThreshold
    var draining = false

    var isEmpty: Bool {
      payloadQueue.isEmpty
    }
  }

  private let runtime: LuaRuntime
  private let logger: ProcessLogger
  private let encoder = JSONEncoder()
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
    let outcome = state.withLock { state -> EnqueueOutcome in
      let pressure: QueuePressure?

      switch EventDeliveryPolicy.forEventName(payload.eventName) {
      case .mustDeliver:
        pressure = enqueueMustDeliver(payload, state: &state)
      case .coalescing:
        pressure = enqueueCoalescing(payload, state: &state)
      }

      let shouldStartDraining = !state.draining
      state.draining = true

      return EnqueueOutcome(
        shouldStartDraining: shouldStartDraining,
        pressure: pressure
      )
    }

    report(outcome.pressure)

    guard outcome.shouldStartDraining else { return }

    Task { [weak self] in
      await self?.drainLoop()
    }
  }

  /// Appends one must-deliver payload without evicting older actions.
  private func enqueueMustDeliver(
    _ payload: EasyBarEventPayload,
    state: inout State
  ) -> QueuePressure? {
    state.payloadQueue.append(
      QueueEntry(
        coalescingKey: nil,
        payload: payload
      )
    )
    state.mustDeliverPayloadCount += 1

    guard state.mustDeliverPayloadCount >= state.nextMustDeliverWarningCount else {
      return nil
    }

    let warningCount = state.mustDeliverPayloadCount
    if state.nextMustDeliverWarningCount <= Int.max / 2 {
      state.nextMustDeliverWarningCount *= 2
    } else {
      state.nextMustDeliverWarningCount = Int.max
    }

    return .mustDeliverBacklog(count: warningCount)
  }

  /// Stores the newest state payload for its target key at the newest queue
  /// position. This preserves enqueue order across action and state events
  /// without letting high-frequency state grow unbounded.
  private func enqueueCoalescing(
    _ payload: EasyBarEventPayload,
    state: inout State
  ) -> QueuePressure? {
    let key = coalescingKey(for: payload)
    var pressure: QueuePressure?

    if let existingIndex = state.coalescedPayloadIndices[key] {
      _ = removeQueuedPayload(at: existingIndex, state: &state)
    } else if state.coalescingPayloadCount >= Self.coalescingQueueLimit,
      let droppedIndex = state.payloadQueue.firstIndex(where: { $0.coalescingKey != nil })
    {
      let dropped = removeQueuedPayload(at: droppedIndex, state: &state)
      pressure = .coalesced(eventName: dropped.payload.eventName)
    }

    state.coalescedPayloadIndices[key] = state.payloadQueue.count
    state.payloadQueue.append(
      QueueEntry(
        coalescingKey: key,
        payload: payload
      )
    )
    state.coalescingPayloadCount += 1

    return pressure
  }

  /// Removes one queued payload and keeps coalescing indices/counts consistent.
  private func removeQueuedPayload(at index: Int, state: inout State) -> QueueEntry {
    let removed = state.payloadQueue.remove(at: index)

    if let key = removed.coalescingKey {
      state.coalescedPayloadIndices.removeValue(forKey: key)
      state.coalescingPayloadCount -= 1
    } else {
      state.mustDeliverPayloadCount -= 1
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

  /// Reports queue pressure without performing logging while the state lock is held.
  private func report(_ pressure: QueuePressure?) {
    switch pressure {
    case .mustDeliverBacklog(let count):
      logger.error(
        "lua must-deliver event backlog is growing",
        .field("queued_actions", count)
      )
    case .coalesced(let eventName):
      logger.warn(
        "coalescing oldest lua state event due to backpressure",
        .field("name", eventName)
      )
    case nil:
      break
    }
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
      state.mustDeliverPayloadCount = 0
      state.coalescingPayloadCount = 0
      state.nextMustDeliverWarningCount = Self.mustDeliverBacklogWarningThreshold

      return payloads
    }
  }

  /// Encodes and sends one payload to the Lua runtime.
  private func send(_ payload: EasyBarEventPayload) async {
    guard let encoded = encodeJSON(payload.luaPayload) else {
      logger.error(
        "failed to encode lua event payload",
        .field("name", payload.eventName)
      )
      return
    }

    await runtime.send(encoded)
  }

  /// Encodes one event payload as JSON for the Lua runtime.
  private func encodeJSON(_ payload: LuaEventPayload) -> String? {
    guard
      let data = try? encoder.encode(payload),
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
