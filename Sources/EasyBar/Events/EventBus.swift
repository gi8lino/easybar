import Foundation

final class EventBus {

    static let shared = EventBus()

    private let runtime = LuaRuntime.shared

    private init() {}

    func emit(_ event: String, data: [String: String] = [:]) {
        var payload = data
        payload["event"] = event

        // Native widgets subscribe here.
        NotificationCenter.default.post(name: .easyBarEvent, object: payload)

        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: json, encoding: .utf8) else {
            return
        }

        Logger.debug("emit event \(event)")
        runtime.send(string)
    }

    func emitWidgetEvent(_ event: String, widgetID: String, data: [String: String] = [:]) {
        var payload = data
        payload["widget"] = widgetID
        emit(event, data: payload)
    }
}

extension Notification.Name {
    static let easyBarEvent = Notification.Name("easybar.event")
}
