import Foundation

/// Actor-owned event hub for native widgets and the Lua runtime.
actor EventHub {
  static let shared = EventHub()

  private let luaEventSink = LuaEventSink()
  private var subscribers: [UUID: Subscriber] = [:]
  private var replayablePayloads: [String: EasyBarEventPayload] = [:]

  private struct Subscriber {
    let eventNames: Set<String>?
    let widgetTargetIDs: Set<String>?
    let continuation: AsyncStream<EasyBarEventPayload>.Continuation
  }

  /// Subscribes to the app-wide event stream.
  func subscribe(
    eventNames: Set<String>? = nil,
    widgetTargetIDs: Set<String>? = nil,
    replayLatest: Bool = false,
    bufferingPolicy: AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy? = nil
  ) -> AsyncStream<EasyBarEventPayload> {
    let id = UUID()
    let resolvedBufferingPolicy = bufferingPolicy ?? EventDeliveryPolicy.defaultBufferingPolicy(
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
  func emit(_ event: AppEvent) async {
    await emit(.app(event))
  }

  /// Emits one app-wide event with app name context.
  func emit(_ event: AppEvent, appName: String) async {
    await emit(.app(event, appName: appName))
  }

  /// Emits one app-wide event with interface name context.
  func emit(_ event: AppEvent, interfaceName: String) async {
    await emit(.app(event, interfaceName: interfaceName))
  }

  /// Emits one app-wide event with charging state context.
  func emit(_ event: AppEvent, charging: Bool) async {
    await emit(.app(event, charging: charging))
  }

  /// Emits one app-wide event with muted state context.
  func emit(_ event: AppEvent, muted: Bool) async {
    await emit(.app(event, muted: muted))
  }

  /// Emits one app-wide event with tunnel-state context.
  func emit(_ event: AppEvent, primaryInterfaceIsTunnel: Bool) async {
    await emit(.app(event, primaryInterfaceIsTunnel: primaryInterfaceIsTunnel))
  }

  /// Emits one widget-scoped interaction event.
  func emitWidgetEvent(
    _ event: WidgetEvent,
    widgetID: String,
    targetWidgetID: String? = nil,
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
    MetricsCoordinator.shared.recordEvent(
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
        MetricsCoordinator.shared.recordEventBackpressure(
          name: payload.eventName,
          coalesced: deliveryPolicy == .coalescing
        )
      }
    }

    logEmission(payload)
    luaEventSink.enqueue(payload)
  }

  /// Emits the latest replayable state for the requested event names.
  func emitReplayableState(for eventNames: Set<String>) async {
    let payloads = await EventReplayCatalog.payloads(for: eventNames)

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

  /// Logs one emitted payload for verbose debugging.
  private func logEmission(_ payload: EasyBarEventPayload) {
    guard !payload.eventName.isEmpty else { return }
    easybarLog.trace("emit event \(payload.eventName) payload=\(payload.toDictionary())")
  }
}
