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
        EasyBarEventPayload(
            appEvent: event,
            widgetEvent: nil,
            widgetID: nil,
            appName: appName,
            interfaceName: interfaceName,
            button: nil,
            direction: nil,
            charging: charging,
            muted: muted,
            value: nil,
            deltaX: nil,
            deltaY: nil
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
        EasyBarEventPayload(
            appEvent: nil,
            widgetEvent: event,
            widgetID: widgetID,
            appName: nil,
            interfaceName: nil,
            button: button,
            direction: direction,
            charging: nil,
            muted: nil,
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

        if let appEvent {
            payload["event"] = appEvent.rawValue
        }

        if let widgetEvent {
            payload["event"] = widgetEvent.rawValue
        }

        if let widgetID {
            payload["widget"] = widgetID
        }

        if let appName {
            payload["app"] = appName
        }

        if let interfaceName {
            payload["interface"] = interfaceName
        }

        if let button {
            payload["button"] = button.rawValue
        }

        if let direction {
            payload["direction"] = direction.rawValue
        }

        if let charging {
            payload["charging"] = charging ? "true" : "false"
        }

        if let muted {
            payload["muted"] = muted ? "true" : "false"
        }

        if let value {
            payload["value"] = String(value)
        }

        if let deltaX {
            payload["delta_x"] = String(deltaX)
        }

        if let deltaY {
            payload["delta_y"] = String(deltaY)
        }

        return payload
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
