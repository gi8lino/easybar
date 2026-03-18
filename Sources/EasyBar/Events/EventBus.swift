import Foundation

/// Central event bridge for both native Swift widgets and the Lua runtime.
final class EventBus {

    static let shared = EventBus()

    private let runtime = LuaRuntime.shared

    private init() {}

    /// Emits one app-wide event to native widgets and the Lua runtime.
    func emit(_ event: AppEvent) {
        emit(.app(event))
    }

    /// Emits one app-wide event with app name context.
    func emit(_ event: AppEvent, appName: String) {
        emit(.app(event, appName: appName))
    }

    /// Emits one app-wide event with interface name context.
    func emit(_ event: AppEvent, interfaceName: String) {
        emit(.app(event, interfaceName: interfaceName))
    }

    /// Emits one app-wide event with charging state context.
    func emit(_ event: AppEvent, charging: Bool) {
        emit(.app(event, charging: charging))
    }

    /// Emits one app-wide event with muted state context.
    func emit(_ event: AppEvent, muted: Bool) {
        emit(.app(event, muted: muted))
    }

    /// Emits one widget-scoped event to native widgets and the Lua runtime.
    func emitWidgetEvent(
        _ event: WidgetEvent,
        widgetID: String,
        button: MouseButton? = nil,
        direction: ScrollDirection? = nil,
        value: Double? = nil,
        deltaX: Double? = nil,
        deltaY: Double? = nil
    ) {
        emit(.widget(
            event,
            widgetID: widgetID,
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

        if let appEvent = payload.appEvent {
            Logger.debug("emit event \(appEvent.rawValue)")
        } else if let widgetEvent = payload.widgetEvent {
            Logger.debug("emit widget event \(widgetEvent.rawValue) widget=\(payload.widgetID ?? "")")
        }

        sendToLua(payload)
    }

    /// Encodes and forwards one payload to the Lua runtime.
    private func sendToLua(_ payload: EasyBarEventPayload) {
        guard let encoded = encodeJSON(payload.toDictionary()) else {
            Logger.error("failed to encode lua event payload")
            return
        }

        runtime.send(encoded)
    }

    /// Encodes one event payload as JSON for the Lua runtime.
    private func encodeJSON(_ payload: [String: String]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }
}

extension Notification.Name {
    static let easyBarEvent = Notification.Name("easybar.event")
}
