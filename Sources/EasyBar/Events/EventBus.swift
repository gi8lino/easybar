import Foundation

/// Central event bridge for both native Swift widgets and the Lua runtime.
final class EventBus {

  static let shared = EventBus()

  private let runtime = LuaRuntime.shared

  private init() {}

  /// Emits one app-wide event to native widgets and the Lua runtime.
  func emit(_ event: AppEvent) {
    emitApp(.app(event))
  }

  /// Emits one app-wide event with app name context.
  func emit(_ event: AppEvent, appName: String) {
    emitApp(.app(event, appName: appName))
  }

  /// Emits one app-wide event with interface name context.
  func emit(_ event: AppEvent, interfaceName: String) {
    emitApp(.app(event, interfaceName: interfaceName))
  }

  /// Emits one app-wide event with charging state context.
  func emit(_ event: AppEvent, charging: Bool) {
    emitApp(.app(event, charging: charging))
  }

  /// Emits one app-wide event with muted state context.
  func emit(_ event: AppEvent, muted: Bool) {
    emitApp(.app(event, muted: muted))
  }

  /// Emits one widget-scoped event to native widgets and the Lua runtime.
  func emitWidgetEvent(
    _ event: WidgetEvent,
    widgetID: String,
    targetWidgetID: String? = nil,
    button: MouseButton? = nil,
    direction: ScrollDirection? = nil,
    value: Double? = nil,
    deltaX: Double? = nil,
    deltaY: Double? = nil
  ) {
    emitWidget(
      .widget(
        event,
        widgetID: widgetID,
        targetWidgetID: targetWidgetID,
        button: button,
        direction: direction,
        value: value,
        deltaX: deltaX,
        deltaY: deltaY
      ))
  }

  /// Emits one typed event payload.
  func emit(_ payload: EasyBarEventPayload) {
    NotificationCenter.default.post(name: .easyBarEvent, object: payload)
    logEmission(payload)
    sendToLua(payload)
  }

  /// Encodes and forwards one payload to the Lua runtime.
  private func sendToLua(_ payload: EasyBarEventPayload) {
    guard let encoded = encodedPayload(payload) else {
      Logger.error("failed to encode lua event payload")
      return
    }

    runtime.send(encoded)
  }

  /// Returns the encoded Lua payload string.
  private func encodedPayload(_ payload: EasyBarEventPayload) -> String? {
    encodeJSON(payload.toDictionary())
  }

  /// Encodes one event payload as JSON for the Lua runtime.
  private func encodeJSON(_ payload: [String: String]) -> String? {
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
      let string = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return string
  }

  /// Emits one already-constructed app payload.
  private func emitApp(_ payload: EasyBarEventPayload) {
    emit(payload)
  }

  /// Emits one already-constructed widget payload.
  private func emitWidget(_ payload: EasyBarEventPayload) {
    emit(payload)
  }

  /// Logs one emitted payload for local debugging.
  private func logEmission(_ payload: EasyBarEventPayload) {
    guard let line = payload.debugDescription else { return }
    Logger.debug(line)
  }
}

extension Notification.Name {
  static let easyBarEvent = Notification.Name("easybar.event")
}
