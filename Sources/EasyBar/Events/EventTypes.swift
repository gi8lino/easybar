import Foundation

/// App-wide events emitted by EasyBar.
enum AppEvent: String {
    case forced = "forced"

    case systemWoke = "system_woke"
    case sleep = "sleep"
    case spaceChange = "space_change"
    case appSwitch = "app_switch"
    case displayChange = "display_change"

    case powerSourceChange = "power_source_change"
    case chargingStateChange = "charging_state_change"

    case networkChange = "network_change"
    case wifiChange = "wifi_change"

    case volumeChange = "volume_change"
    case muteChange = "mute_change"

    case calendarChange = "calendar_change"

    case minuteTick = "minute_tick"
    case secondTick = "second_tick"

    case focusChange = "focus_change"
    case workspaceChange = "workspace_change"
}

/// Widget-scoped interaction events emitted by EasyBar.
enum WidgetEvent: String {
    case mouseEntered = "mouse.entered"
    case mouseExited = "mouse.exited"
    case mouseDown = "mouse.down"
    case mouseUp = "mouse.up"
    case mouseClicked = "mouse.clicked"
    case mouseScrolled = "mouse.scrolled"

    case sliderPreview = "slider.preview"
    case sliderChanged = "slider.changed"
}

/// Strongly typed event payload used inside Swift.
///
/// Lua still receives a JSON dictionary at the boundary.
struct EasyBarEventPayload {
    let appEvent: AppEvent?
    let widgetEvent: WidgetEvent?

    let widgetID: String?
    let appName: String?
    let interfaceName: String?
    let button: MouseButton?
    let direction: ScrollDirection?
    let charging: Bool?
    let muted: Bool?
    let value: Double?
    let deltaX: Double?
    let deltaY: Double?

    /// Creates one app-wide event payload.
    static func app(
        _ event: AppEvent,
        appName: String? = nil,
        interfaceName: String? = nil,
        charging: Bool? = nil,
        muted: Bool? = nil
    ) -> EasyBarEventPayload {
        makePayload(
            appEvent: event,
            appName: appName,
            interfaceName: interfaceName,
            charging: charging,
            muted: muted,
        )
    }

    /// Creates one widget-scoped event payload.
    static func widget(
        _ event: WidgetEvent,
        widgetID: String,
        button: MouseButton? = nil,
        direction: ScrollDirection? = nil,
        value: Double? = nil,
        deltaX: Double? = nil,
        deltaY: Double? = nil
    ) -> EasyBarEventPayload {
        makePayload(
            widgetEvent: event,
            widgetID: widgetID,
            button: button,
            direction: direction,
            value: value,
            deltaX: deltaX,
            deltaY: deltaY
        )
    }

    /// Returns the raw event name used by Lua.
    var eventName: String {
        appEvent?.rawValue ?? widgetEvent?.rawValue ?? ""
    }

    /// Encodes this payload for the Lua runtime boundary.
    func toDictionary() -> [String: String] {
        var payload: [String: String] = [:]

        put(&payload, key: "event", value: resolvedEventName)
        put(&payload, key: "widget", value: widgetID)
        put(&payload, key: "app", value: appName)
        put(&payload, key: "interface", value: interfaceName)
        put(&payload, key: "button", value: button?.rawValue)
        put(&payload, key: "direction", value: direction?.rawValue)
        put(&payload, key: "charging", value: charging)
        put(&payload, key: "muted", value: muted)
        put(&payload, key: "value", value: value)
        put(&payload, key: "delta_x", value: deltaX)
        put(&payload, key: "delta_y", value: deltaY)

        return payload
    }

    /// Stores one optional string value in the Lua payload.
    private func put(_ payload: inout [String: String], key: String, value: String?) {
        guard let value else { return }
        payload[key] = value
    }

    /// Stores one optional Bool value in the Lua payload.
    private func put(_ payload: inout [String: String], key: String, value: Bool?) {
        guard let value else { return }
        payload[key] = value ? "true" : "false"
    }

    /// Stores one optional numeric value in the Lua payload.
    private func put(_ payload: inout [String: String], key: String, value: Double?) {
        guard let value else { return }
        payload[key] = String(value)
    }

    /// Builds one strongly typed event payload.
    private static func makePayload(
        appEvent: AppEvent? = nil,
        widgetEvent: WidgetEvent? = nil,
        widgetID: String? = nil,
        appName: String? = nil,
        interfaceName: String? = nil,
        button: MouseButton? = nil,
        direction: ScrollDirection? = nil,
        charging: Bool? = nil,
        muted: Bool? = nil,
        value: Double? = nil,
        deltaX: Double? = nil,
        deltaY: Double? = nil
    ) -> EasyBarEventPayload {
        EasyBarEventPayload(
            appEvent: appEvent,
            widgetEvent: widgetEvent,
            widgetID: widgetID,
            appName: appName,
            interfaceName: interfaceName,
            button: button,
            direction: direction,
            charging: charging,
            muted: muted,
            value: value,
            deltaX: deltaX,
            deltaY: deltaY
        )
    }

    /// Returns the non-empty event name used at the Lua boundary.
    private var resolvedEventName: String? {
        let name = eventName
        guard !name.isEmpty else { return nil }
        return name
    }
}

/// Mouse button names used by widget interaction events.
enum MouseButton: String {
    case left
    case right
    case middle
}

/// Scroll direction names used by widget interaction events.
enum ScrollDirection: String {
    case up
    case down
}
