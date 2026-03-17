import Foundation

/// Central event bridge for both native Swift widgets and the Lua runtime.
final class EventBus {

    static let shared = EventBus()

    private let runtime = LuaRuntime.shared

    private init() {}

    /// Emits one app-wide event to native widgets and the Lua runtime.
    func emit(_ event: AppEvent, data: [String: String] = [:]) {
        var payload = data
        payload["event"] = event.rawValue

        // Native widgets observe these through NotificationCenter.
        NotificationCenter.default.post(name: .easyBarEvent, object: payload)

        Logger.debug("emit event \(event.rawValue)")

        sendToLua(payload)
    }

    /// Emits one widget-scoped event to native widgets and the Lua runtime.
    ///
    /// Mouse and slider events must also reach Lua, otherwise Lua widgets
    /// cannot react to hover, click, scroll, or slider changes.
    func emitWidgetEvent(_ event: WidgetEvent, widgetID: String, data: [String: String] = [:]) {
        var payload = data
        payload["widget"] = widgetID
        payload["event"] = event.rawValue

        // Native widgets observe these through NotificationCenter.
        NotificationCenter.default.post(name: .easyBarEvent, object: payload)

        Logger.debug("emit widget event \(event.rawValue) widget=\(widgetID)")

        sendToLua(payload)
    }

    /// Encodes and forwards one payload to the Lua runtime.
    private func sendToLua(_ payload: [String: String]) {
        guard let encoded = encodeJSON(payload) else {
            Logger.info("failed to encode lua event payload")
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
