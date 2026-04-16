import Foundation

/// Actor-owned event hub for native widgets and the Lua runtime.
actor EventHub {
  static let shared = EventHub()

  private let runtime = LuaRuntime.shared
  private var continuations: [UUID: AsyncStream<EasyBarEventPayload>.Continuation] = [:]

  /// Subscribes to the app-wide event stream.
  func subscribe() -> AsyncStream<EasyBarEventPayload> {
    let id = UUID()

    return AsyncStream { continuation in
      continuations[id] = continuation

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

    for continuation in continuations.values {
      continuation.yield(payload)
    }

    logEmission(payload)
    await sendToLua(payload)
  }

  /// Removes one terminated subscription.
  private func removeContinuation(id: UUID) {
    continuations.removeValue(forKey: id)
  }

  /// Sends one payload to the Lua runtime stdin.
  private func sendToLua(_ payload: EasyBarEventPayload) async {
    guard let encoded = encodedPayload(payload) else {
      easybarLog.error("failed to encode lua event payload name=\(payload.eventName)")
      return
    }

    easybarLog.trace("sent to lua stdin: \(encoded)")
    await runtime.send(encoded)
  }

  /// Returns the encoded Lua payload string.
  private func encodedPayload(_ payload: EasyBarEventPayload) -> String? {
    encodeJSON(payload.toDictionary())
  }

  /// Encodes one event payload as JSON for the Lua runtime.
  private func encodeJSON(_ payload: [String: Any]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
      let string = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return string
  }

  /// Logs one emitted payload for verbose debugging.
  private func logEmission(_ payload: EasyBarEventPayload) {
    guard !payload.eventName.isEmpty else { return }
    easybarLog.trace("emit event \(payload.eventName) payload=\(payload.toDictionary())")
  }
}
