import EasyBarShared
import Foundation

/// Actor-owned event hub for native widgets and the Lua runtime.
actor EventHub {
  /// Prefix used for Lua interval subscriptions.
  private static let intervalTickPrefix = "interval_tick:"

  /// Logger used for event diagnostics.
  private let logger: ProcessLogger
  /// Sink that forwards selected events into Lua.
  private let enqueueLuaEvent: @Sendable (EasyBarEventPayload) -> Void
  private let metricsCoordinator: MetricsCoordinator
  private let wifiSnapshotProvider: @MainActor @Sendable () -> NetworkAgentSnapshot?

  /// Active stream subscribers keyed by id.
  private var subscribers: [UUID: Subscriber] = [:]
  /// Latest payload cached for each replayable event.
  private var replayablePayloads: [String: EasyBarEventPayload] = [:]
  /// App events currently requested by Lua.
  private var luaForwardedAppEvents = Set<String>()

  /// Subscriber filters and continuation.
  private struct Subscriber {
    /// Optional event-name filter.
    let eventNames: Set<String>?
    /// Optional widget target filter.
    let widgetTargetIDs: Set<String>?
    /// Stream continuation used to deliver payloads.
    let continuation: AsyncStream<EasyBarEventPayload>.Continuation
  }

  /// Creates one production event hub.
  init(
    logger: ProcessLogger,
    luaRuntime: LuaRuntime,
    metricsCoordinator: MetricsCoordinator,
    wifiSnapshotProvider: @escaping @MainActor @Sendable () -> NetworkAgentSnapshot?
  ) {
    self.init(
      logger: logger,
      enqueueLuaEvent: {
        let sink = LuaEventSink(
          runtime: luaRuntime,
          logger: logger.child("lua_sink")
        )
        return { @Sendable payload in sink.enqueue(payload) }
      }(),
      metricsCoordinator: metricsCoordinator,
      wifiSnapshotProvider: wifiSnapshotProvider
    )
  }

  /// Creates one event hub with an injected sink.
  init(
    logger: ProcessLogger,
    enqueueLuaEvent: @escaping @Sendable (EasyBarEventPayload) -> Void,
    metricsCoordinator: MetricsCoordinator = .shared,
    wifiSnapshotProvider: @escaping @MainActor @Sendable () -> NetworkAgentSnapshot? = { nil }
  ) {
    self.logger = logger
    self.enqueueLuaEvent = enqueueLuaEvent
    self.metricsCoordinator = metricsCoordinator
    self.wifiSnapshotProvider = wifiSnapshotProvider
  }

  /// Subscribes to the app-wide event stream.
  func subscribe(
    eventNames: Set<String>? = nil,
    widgetTargetIDs: Set<String>? = nil,
    replayLatest: Bool = false,
    bufferingPolicy: AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy? = nil
  ) -> AsyncStream<EasyBarEventPayload> {
    let id = UUID()
    let resolvedBufferingPolicy =
      bufferingPolicy
      ?? EventDeliveryPolicy.defaultBufferingPolicy(
        for: eventNames
      )

    return AsyncStream(bufferingPolicy: resolvedBufferingPolicy) { continuation in
      let normalizedEventNames = eventNames?.isEmpty == true ? nil : eventNames
      let normalizedWidgetTargetIDs = widgetTargetIDs?.isEmpty == true ? nil : widgetTargetIDs

      subscribers[id] = Subscriber(
        eventNames: normalizedEventNames,
        widgetTargetIDs: normalizedWidgetTargetIDs,
        continuation: continuation
      )

      if replayLatest {
        for eventName in EventReplayCatalog.orderedEventNames {
          if let normalizedEventNames, !normalizedEventNames.contains(eventName) {
            continue
          }

          guard let payload = replayablePayloads[eventName] else { continue }
          continuation.yield(payload)
        }
      }

      continuation.onTermination = { [weak self] _ in
        Task {
          await self?.removeContinuation(id: id)
        }
      }
    }
  }

  /// Emits one app-wide event.
  func emit(_ event: AppEvent, source: String? = nil) async {
    await emit(.app(event, source: source))
  }

  /// Emits one widget-scoped interaction event.
  func emitWidgetEvent(
    _ event: WidgetEvent,
    widgetID: String,
    targetWidgetID: String? = nil,
    source: String? = nil,
    button: MouseButton? = nil,
    direction: ScrollDirection? = nil,
    value: Double? = nil,
    deltaX: Double? = nil,
    deltaY: Double? = nil
  ) async {
    await emit(
      .widget(
        event,
        widgetID: widgetID,
        targetWidgetID: targetWidgetID,
        source: source,
        button: button,
        direction: direction,
        value: value,
        deltaX: deltaX,
        deltaY: deltaY
      )
    )
  }

  /// Emits one fully constructed payload.
  func emit(_ payload: EasyBarEventPayload) async {
    await metricsCoordinator.recordEvent(
      name: payload.eventName,
      isWidgetEvent: payload.widgetEvent != nil
    )

    if EventReplayCatalog.isReplayable(payload.eventName) {
      replayablePayloads[payload.eventName] = payload
    }

    let deliveryPolicy = EventDeliveryPolicy.forEventName(payload.eventName)

    for subscriber in subscribers.values {
      guard shouldDeliver(payload, to: subscriber) else { continue }

      let result = subscriber.continuation.yield(payload)

      if case .dropped = result {
        await metricsCoordinator.recordEventBackpressure(
          name: payload.eventName,
          coalesced: deliveryPolicy == .coalescing
        )
      }
    }

    logEmission(payload)

    if shouldForwardPayloadToLua(payload) {
      enqueueLuaEvent(payload)
    }
  }

  /// Replaces the set of app-level events that may be forwarded into Lua.
  func setLuaForwardedAppEvents(_ eventNames: Set<String>) {
    luaForwardedAppEvents = eventNames
  }

  /// Clears all app-level event forwarding for the Lua runtime.
  func clearLuaForwardedAppEvents() {
    luaForwardedAppEvents.removeAll()
  }

  /// Emits the latest replayable state for the requested event names.
  func emitReplayableState(for eventNames: Set<String>) async {
    let payloads = await EventReplayCatalog.payloads(
      for: eventNames,
      wifiSnapshotProvider: wifiSnapshotProvider
    )

    for payload in payloads {
      await emit(payload)
    }
  }

  /// Removes one terminated subscription.
  private func removeContinuation(id: UUID) {
    subscribers.removeValue(forKey: id)
  }

  /// Returns whether one payload matches one subscriber filter.
  private func shouldDeliver(_ payload: EasyBarEventPayload, to subscriber: Subscriber) -> Bool {
    if let eventNames = subscriber.eventNames, !eventNames.contains(payload.eventName) {
      return false
    }

    guard EventDeliveryPolicy.routesDirectlyToWidgets(payload.eventName) else {
      return true
    }

    guard let widgetTargetIDs = subscriber.widgetTargetIDs else {
      return true
    }

    let widgetIDs = [payload.widgetID, payload.targetWidgetID].compactMap { $0 }
    return widgetIDs.contains { widgetTargetIDs.contains($0) }
  }

  /// Returns whether one payload should be forwarded into the Lua runtime.
  private func shouldForwardPayloadToLua(_ payload: EasyBarEventPayload) -> Bool {
    if payload.widgetEvent != nil {
      return true
    }

    guard let appEvent = payload.appEvent else {
      return false
    }

    if appEvent == .intervalTick {
      return luaForwardedAppEvents.contains { $0.hasPrefix(Self.intervalTickPrefix) }
    }

    return luaForwardedAppEvents.contains(appEvent.rawValue)
  }

  /// Logs one emitted payload for verbose debugging.
  private func logEmission(_ payload: EasyBarEventPayload) {
    guard !payload.eventName.isEmpty else { return }

    logger.trace(
      "emit event",
      .field("name", payload.eventName),
      .field("source", payload.source ?? "<unknown>"),
      .field("payload_keys", payload.luaPayloadKeys)
    )
  }
}
