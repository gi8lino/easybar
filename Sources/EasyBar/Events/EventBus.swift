import Foundation

final class EventBus {

    static let shared = EventBus()

    private let runtime = LuaRuntime.shared

    private init() {}

    /// Emits one event to native widgets and the Lua runtime.
    func emit(_ event: String, data: [String: String] = [:]) {
        var payload = data
        payload["event"] = event

        // Native widgets subscribe through NotificationCenter.
        NotificationCenter.default.post(name: .easyBarEvent, object: payload)

        Logger.debug("emit event \(event)")

        guard let encoded = encodeJSON(payload) else {
            Logger.info("failed to encode lua event payload")
            return
        }

        runtime.send(encoded)
    }

    /// Emits one widget-scoped event.
    func emitWidgetEvent(_ event: String, widgetID: String, data: [String: String] = [:]) {
        var payload = data
        payload["widget"] = widgetID
        emit(event, data: payload)
    }

    /// Encodes the Lua event payload as JSON.
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
