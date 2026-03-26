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
    let targetWidgetID: String?
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
        targetWidgetID: String? = nil,
        button: MouseButton? = nil,
        direction: ScrollDirection? = nil,
        value: Double? = nil,
        deltaX: Double? = nil,
        deltaY: Double? = nil
    ) -> EasyBarEventPayload {
        makePayload(
            widgetEvent: event,
            widgetID: widgetID,
            targetWidgetID: targetWidgetID,
            button: button,
            direction: direction,
            value: value,
            deltaX: deltaX,
            deltaY: deltaY
        )
    }

    /// Returns the raw event name used by Lua.
    var eventName: String {
        appEventName ?? widgetEventName ?? ""
    }

    /// Returns whether this payload has a non-empty event name.
    private var hasEventName: Bool {
        !eventName.isEmpty
    }

    /// Returns the debug log line for this payload.
    var debugDescription: String? {
        if isAppEvent {
            guard let appEventName else { return nil }
            return "emit event \(appEventName)"
        }

        guard isWidgetEvent else { return nil }
        guard let widgetEventName else { return nil }
        return "emit widget event \(widgetEventName) widget=\(resolvedWidgetID)"
    }

    /// Encodes this payload for the Lua runtime boundary.
    func toDictionary() -> [String: String] {
        var payload: [String: String] = [:]

        put(&payload, key: "event", value: resolvedEventName)
        put(&payload, key: "widget", value: widgetID)
        put(&payload, key: "target_widget", value: targetWidgetID)
        put(&payload, key: "app", value: appName)
        put(&payload, key: "interface", value: interfaceName)
        put(&payload, key: "button", value: buttonName)
        put(&payload, key: "direction", value: directionName)
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
        targetWidgetID: String? = nil,
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
            targetWidgetID: targetWidgetID,
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
        guard hasEventName else { return nil }
        return eventName
    }

    /// Returns the raw app event name.
    private var appEventName: String? {
        appEvent?.rawValue
    }

    /// Returns whether this payload carries an app event.
    private var isAppEvent: Bool {
        appEvent != nil
    }

    /// Returns the raw widget event name.
    private var widgetEventName: String? {
        widgetEvent?.rawValue
    }

    /// Returns whether this payload carries a widget event.
    private var isWidgetEvent: Bool {
        widgetEvent != nil
    }

    /// Returns the raw mouse button name.
    private var buttonName: String? {
        button?.rawValue
    }

    /// Returns the widget id used in debug logs.
    private var resolvedWidgetID: String {
        widgetID ?? ""
    }

    /// Returns the raw scroll direction name.
    private var directionName: String? {
        direction?.rawValue
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
