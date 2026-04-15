import Foundation

/// Central event bridge for both native Swift widgets and the Lua runtime.
final class EventBus {

  static let shared = EventBus()

  private let runtime = LuaRuntime.shared
  private let luaSendQueue = DispatchQueue(label: "com.gi8lino.easybar.eventbus.lua-send")

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

  /// Emits one app-wide event with tunnel-state context.
  func emit(_ event: AppEvent, primaryInterfaceIsTunnel: Bool) {
    emitApp(.app(event, primaryInterfaceIsTunnel: primaryInterfaceIsTunnel))
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
    let threadLabel = Thread.isMainThread ? "main" : "background"
    easybarLog.trace("emit begin name=\(payload.eventName) thread=\(threadLabel)")

    MetricsCoordinator.shared.recordEvent(
      name: payload.eventName,
      isWidgetEvent: payload.widgetEvent != nil
    )

    let nativeStart = Date()
    NotificationCenter.default.post(name: .easyBarEvent, object: payload)
    logSlowPhase(
      name: "native delivery",
      eventName: payload.eventName,
      startedAt: nativeStart
    )

    logEmission(payload)
    sendToLuaAsync(payload)

    easybarLog.trace("emit end name=\(payload.eventName) thread=\(threadLabel)")
  }

  /// Encodes and forwards one payload to the Lua runtime on a dedicated serial queue.
  private func sendToLuaAsync(_ payload: EasyBarEventPayload) {
    luaSendQueue.async { [weak self] in
      self?.sendToLua(payload)
    }
  }

  /// Encodes and forwards one payload to the Lua runtime.
  private func sendToLua(_ payload: EasyBarEventPayload) {
    let encodeStart = Date()

    guard let encoded = encodedPayload(payload) else {
      easybarLog.error("failed to encode lua event payload name=\(payload.eventName)")
      return
    }

    logSlowPhase(
      name: "lua payload encode",
      eventName: payload.eventName,
      startedAt: encodeStart
    )

    let sendStart = Date()
    easybarLog.trace("sent to lua stdin: \(encoded)")
    runtime.send(encoded)
    logSlowPhase(
      name: "lua send",
      eventName: payload.eventName,
      startedAt: sendStart
    )
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

  /// Emits one already-constructed app payload.
  private func emitApp(_ payload: EasyBarEventPayload) {
    emit(payload)
  }

  /// Emits one already-constructed widget payload.
  private func emitWidget(_ payload: EasyBarEventPayload) {
    emit(payload)
  }

  /// Logs one emitted payload for verbose debugging.
  private func logEmission(_ payload: EasyBarEventPayload) {
    guard !payload.eventName.isEmpty else { return }
    easybarLog.trace("emit event \(payload.eventName) payload=\(payload.toDictionary())")
  }

  /// Logs one phase duration when it looks unexpectedly slow.
  private func logSlowPhase(
    name: String,
    eventName: String,
    startedAt: Date,
    slowThreshold: TimeInterval = 0.1
  ) {
    let elapsed = Date().timeIntervalSince(startedAt)
    guard elapsed >= slowThreshold else { return }

    let milliseconds = Int((elapsed * 1000).rounded())
    easybarLog.warn("slow event phase phase=\(name) event=\(eventName) duration_ms=\(milliseconds)")
  }
}

extension Notification.Name {
  static let easyBarEvent = Notification.Name("easybar.event")
}
