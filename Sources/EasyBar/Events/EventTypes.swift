import Foundation

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
