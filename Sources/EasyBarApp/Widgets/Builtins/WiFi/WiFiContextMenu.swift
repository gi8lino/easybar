import Foundation

/// Session actions exposed by the native Wi-Fi widget context menu.
enum WiFiContextMenuAction: Equatable {
  case setMode(Config.BuiltinWiFiContentMode)
  case toggleField(String)
  case refresh
  case openNetworkSettings
  case resetToConfig

  /// Decodes one stable context-menu action identifier.
  init?(id: String) {
    if let rawMode = id.removingPrefix("wifi.mode."),
      let mode = Config.BuiltinWiFiContentMode(rawValue: rawMode)
    {
      self = .setMode(mode)
      return
    }

    if let field = id.removingPrefix("wifi.field."),
      BuiltinWiFiFieldCatalog.fields.contains(where: { $0.configKey == field })
    {
      self = .toggleField(field)
      return
    }

    switch id {
    case "wifi.refresh": self = .refresh
    case "wifi.open_network_settings": self = .openNetworkSettings
    case "wifi.reset_to_config": self = .resetToConfig
    default: return nil
    }
  }
}

/// Builds the native Wi-Fi context menu from the effective session configuration.
enum WiFiContextMenu {
  static func make(
    config: Config.WiFiBuiltinConfig,
    hasSessionOverrides: Bool
  ) -> [WidgetContextMenuItem] {
    let modes = Config.BuiltinWiFiContentMode.allCases.map { mode in
      WidgetContextMenuItem(
        id: "wifi.mode.\(mode.rawValue)",
        title: mode.rawValue.capitalized,
        checked: config.mode == mode
      )
    }

    let fields = BuiltinWiFiFieldCatalog.fields.map { field in
      WidgetContextMenuItem(
        id: "wifi.field.\(field.configKey)",
        title: field.displayLabel,
        checked: config.fields[keyPath: field.keyPath]
      )
    }

    return [
      WidgetContextMenuItem(title: "Mode", submenu: modes),
      WidgetContextMenuItem(title: "Fields", submenu: fields),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(id: "wifi.refresh", title: "Refresh"),
      WidgetContextMenuItem(
        id: "wifi.open_network_settings",
        title: "Open Network Settings"
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "wifi.reset_to_config",
        title: "Reset to Config",
        enabled: hasSessionOverrides
      ),
    ]
  }
}

extension String {
  /// Removes one prefix and returns the non-empty suffix.
  fileprivate func removingPrefix(_ prefix: String) -> String? {
    guard hasPrefix(prefix) else { return nil }
    let suffix = String(dropFirst(prefix.count))
    return suffix.isEmpty ? nil : suffix
  }
}
