import Foundation

/// Actions exposed by the native front-app widget context menu.
enum FrontAppContextMenuAction: Equatable {
  case hideApplication
  case toggleShowIcon
  case toggleShowName
  case revealInFinder

  /// Decodes one stable context-menu action identifier.
  init?(id: String) {
    switch id {
    case "front_app.hide": self = .hideApplication
    case "front_app.toggle_show_icon": self = .toggleShowIcon
    case "front_app.toggle_show_name": self = .toggleShowName
    case "front_app.reveal_in_finder": self = .revealInFinder
    default: return nil
    }
  }
}

/// Builds the native front-app context menu from config and focused-app state.
enum FrontAppContextMenu {
  static func make(
    config: Config.FrontAppBuiltinConfig,
    hasFocusedApp: Bool,
    canRevealFocusedApp: Bool
  ) -> [WidgetContextMenuItem] {
    [
      WidgetContextMenuItem(
        id: "front_app.hide",
        title: "Hide Application",
        enabled: hasFocusedApp
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "front_app.toggle_show_icon",
        title: "Show Icon",
        enabled: !config.showIcon || config.showName,
        checked: config.showIcon
      ),
      WidgetContextMenuItem(
        id: "front_app.toggle_show_name",
        title: "Show Name",
        enabled: !config.showName || config.showIcon,
        checked: config.showName
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "front_app.reveal_in_finder",
        title: "Open in Finder",
        enabled: canRevealFocusedApp
      ),
    ]
  }
}
