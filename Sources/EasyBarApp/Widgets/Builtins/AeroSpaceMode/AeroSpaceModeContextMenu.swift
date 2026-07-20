import Foundation

/// Actions exposed by the native AeroSpace-mode widget context menu.
enum AeroSpaceModeContextMenuAction: Equatable {
  case setLayout(AeroSpaceLayoutMode)
  case toggleShowIcon
  case toggleShowText
  case openConfig
  case refresh

  /// Decodes one stable context-menu action identifier.
  init?(id: String) {
    if id.hasPrefix("aerospace_mode.layout."),
      let mode = AeroSpaceLayoutMode(
        rawValue: String(id.dropFirst("aerospace_mode.layout.".count))
      ),
      mode != .unknown
    {
      self = .setLayout(mode)
      return
    }

    switch id {
    case "aerospace_mode.toggle_show_icon": self = .toggleShowIcon
    case "aerospace_mode.toggle_show_text": self = .toggleShowText
    case "aerospace_mode.open_config": self = .openConfig
    case "aerospace_mode.refresh": self = .refresh
    default: return nil
    }
  }
}

/// Builds the native AeroSpace-mode context menu from config and live layout state.
enum AeroSpaceModeContextMenu {
  private static let layoutOptions: [(AeroSpaceLayoutMode, String)] = [
    (.hTiles, "Horizontal Tiles"),
    (.vTiles, "Vertical Tiles"),
    (.hAccordion, "Horizontal Accordion"),
    (.vAccordion, "Vertical Accordion"),
    (.floating, "Floating"),
  ]

  static func make(
    config: Config.AeroSpaceModeBuiltinConfig,
    currentLayout: AeroSpaceLayoutMode
  ) -> [WidgetContextMenuItem] {
    let layoutItems = layoutOptions.map { mode, title in
      WidgetContextMenuItem(
        id: "aerospace_mode.layout.\(mode.rawValue)",
        title: title,
        checked: currentLayout == mode
      )
    }

    return [
      WidgetContextMenuItem(title: "Layout", submenu: layoutItems),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "aerospace_mode.toggle_show_icon",
        title: "Show Icon",
        enabled: !config.showIcon || config.showText,
        checked: config.showIcon
      ),
      WidgetContextMenuItem(
        id: "aerospace_mode.toggle_show_text",
        title: "Show Text",
        enabled: !config.showText || config.showIcon,
        checked: config.showText
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "aerospace_mode.open_config",
        title: "Open AeroSpace Config"
      ),
      WidgetContextMenuItem(id: "aerospace_mode.refresh", title: "Refresh AeroSpace State"),
    ]
  }
}
