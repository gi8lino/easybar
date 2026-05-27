import Foundation

/// App-wide events emitted by EasyBar.
enum AppEvent: String, CaseIterable, Sendable {
  case manualRefresh = "manual_refresh"

  case systemWoke = "system_woke"
  case sessionActive = "session_active"
  case sessionInactive = "session_inactive"
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
enum MouseButton: String, CaseIterable, Sendable {
  case left
  case right
  case middle
}

/// Scroll direction names used by widget interaction events.
enum ScrollDirection: String, CaseIterable, Sendable {
  case up
  case down
  case left
  case right
}

/// Strongly typed event payload used inside Swift.
struct EasyBarEventPayload: Sendable {
  /// App-wide event kind, when this is an app event.
  let appEvent: AppEvent?
  /// Widget-scoped event kind, when this is a widget event.
  let widgetEvent: WidgetEvent?

  /// Source widget identifier.
  let widgetID: String?
  /// Target widget identifier for routed events.
  let targetWidgetID: String?
  /// Frontmost app name associated with the event.
  let appName: String?
  /// Network interface name associated with the event.
  let interfaceName: String?
  /// Mouse button associated with the event.
  let button: MouseButton?
  /// Scroll direction associated with the event.
  let direction: ScrollDirection?

  /// Charging state associated with the event.
  let charging: Bool?
  /// Mute state associated with the event.
  let muted: Bool?
  /// Whether the primary network interface is a tunnel.
  let primaryInterfaceIsTunnel: Bool?

  /// Numeric value associated with the event.
  let value: Double?
  /// Horizontal scroll delta.
  let deltaX: Double?
  /// Vertical scroll delta.
  let deltaY: Double?

  // MARK: - Builders

  /// Builds an app-wide event payload.
  static func app(
    _ event: AppEvent,
    widgetID: String? = nil,
    appName: String? = nil,
    interfaceName: String? = nil,
    charging: Bool? = nil,
    muted: Bool? = nil,
    primaryInterfaceIsTunnel: Bool? = nil
  ) -> EasyBarEventPayload {
    makePayload(
      appEvent: event,
      widgetID: widgetID,
      appName: appName,
      interfaceName: interfaceName,
      charging: charging,
      muted: muted,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel
    )
  }

  /// Builds a widget-scoped event payload.
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

  /// Runtime event name.
  var eventName: String {
    return appEvent?.rawValue ?? widgetEvent?.rawValue ?? ""
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

  /// Creates one event payload from optional app or widget context.
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
