import Foundation

/// App-wide events emitted by EasyBar.
enum AppEvent: String, CaseIterable, Sendable {
  case manualRefresh = "manual_refresh"

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
  case intervalTick = "interval_tick"

  case focusChange = "focus_change"
  case workspaceChange = "workspace_change"
  case spaceModeChange = "space_mode_change"

  static let luaTokenEvents: [AppEvent] = [
    .systemWoke,
    .sleep,
    .spaceChange,
    .appSwitch,
    .displayChange,
    .powerSourceChange,
    .chargingStateChange,
    .networkChange,
    .wifiChange,
    .volumeChange,
    .muteChange,
    .calendarChange,
    .minuteTick,
    .secondTick,
    .focusChange,
    .workspaceChange,
    .spaceModeChange,
  ]

  static let luaDriverEvents: [AppEvent] = [
    .systemWoke,
    .sleep,
    .spaceChange,
    .appSwitch,
    .displayChange,
    .powerSourceChange,
    .chargingStateChange,
    .networkChange,
    .wifiChange,
    .volumeChange,
    .muteChange,
    .calendarChange,
    .minuteTick,
    .secondTick,
    .intervalTick,
    .focusChange,
    .workspaceChange,
    .spaceModeChange,
  ]
}

/// Widget-scoped interaction events emitted by EasyBar.
enum WidgetEvent: String, CaseIterable, Sendable {
  case mouseEntered = "mouse.entered"
  case mouseExited = "mouse.exited"
  case mouseDown = "mouse.down"
  case mouseUp = "mouse.up"
  case mouseClicked = "mouse.clicked"
  case mouseScrolled = "mouse.scrolled"

  case sliderPreview = "slider.preview"
  case sliderChanged = "slider.changed"
}

/// Mouse button names used by widget interaction events.
enum MouseButton: String, Sendable {
  case left
  case right
  case middle
}

/// Scroll direction names used by widget interaction events.
enum ScrollDirection: String, Sendable {
  case up
  case down
}

/// Strongly typed event payload used inside Swift.
struct EasyBarEventPayload: Sendable {
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
  let primaryInterfaceIsTunnel: Bool?

  let value: Double?
  let deltaX: Double?
  let deltaY: Double?

  // MARK: - Builders

  static func app(
    _ event: AppEvent,
    appName: String? = nil,
    interfaceName: String? = nil,
    charging: Bool? = nil,
    muted: Bool? = nil,
    primaryInterfaceIsTunnel: Bool? = nil
  ) -> EasyBarEventPayload {
    makePayload(
      appEvent: event,
      appName: appName,
      interfaceName: interfaceName,
      charging: charging,
      muted: muted,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel
    )
  }

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

  // MARK: - Public

  var eventName: String {
    appEvent?.rawValue ?? widgetEvent?.rawValue ?? ""
  }

  /// New structured encoding for Lua.
  func toDictionary() -> [String: Any] {
    var payload: [String: Any] = [
      "name": eventName
    ]

    if let widgetID {
      payload["widget_id"] = widgetID
    }

    if let targetWidgetID {
      payload["target_widget_id"] = targetWidgetID
    }

    if let button {
      payload["button"] = button.rawValue
    }

    if let direction {
      payload["direction"] = direction.rawValue
    }

    if let value {
      payload["value"] = value
    }

    if let deltaX {
      payload["delta_x"] = deltaX
    }

    if let deltaY {
      payload["delta_y"] = deltaY
    }

    if primaryInterfaceIsTunnel != nil || interfaceName != nil {
      var network: [String: Any] = [:]

      if let primaryInterfaceIsTunnel {
        network["primary_interface_is_tunnel"] = primaryInterfaceIsTunnel
      }

      if let interfaceName {
        network["interface_name"] = interfaceName
      }

      payload["network"] = network
    }

    if let charging {
      payload["power"] = [
        "charging": charging
      ]
    }

    if muted != nil || value != nil {
      var audio: [String: Any] = [:]

      if let muted {
        audio["muted"] = muted
      }

      if let value {
        audio["value"] = value
      }

      payload["audio"] = audio
    }

    if let appName {
      payload["app_name"] = appName
    }

    return payload
  }

  // MARK: - Internal

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
    primaryInterfaceIsTunnel: Bool? = nil,
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
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      value: value,
      deltaX: deltaX,
      deltaY: deltaY
    )
  }
}
