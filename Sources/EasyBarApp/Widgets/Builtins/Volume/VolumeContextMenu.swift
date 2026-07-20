import Foundation

/// Actions exposed by the native volume widget context menu.
enum VolumeContextMenuAction: Equatable {
  case toggleMute
  case toggleShowPercentage
  case toggleExpandOnHover
  case openSoundSettings

  /// Decodes one stable context-menu action identifier.
  init?(id: String) {
    switch id {
    case "volume.toggle_mute": self = .toggleMute
    case "volume.toggle_show_percentage": self = .toggleShowPercentage
    case "volume.toggle_expand_on_hover": self = .toggleExpandOnHover
    case "volume.open_sound_settings": self = .openSoundSettings
    default: return nil
    }
  }
}

/// Builds the native volume context menu from current audio and config state.
enum VolumeContextMenu {
  static func make(
    config: Config.VolumeBuiltinConfig,
    isMuted: Bool
  ) -> [WidgetContextMenuItem] {
    [
      WidgetContextMenuItem(
        id: "volume.toggle_mute",
        title: isMuted ? "Unmute" : "Mute"
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "volume.toggle_show_percentage",
        title: "Show Percentage",
        checked: config.showPercentage
      ),
      WidgetContextMenuItem(
        id: "volume.toggle_expand_on_hover",
        title: "Expand Slider on Hover",
        checked: config.expandToSliderOnHover
      ),
      WidgetContextMenuItem(separator: true),
      WidgetContextMenuItem(
        id: "volume.open_sound_settings",
        title: "Open Sound Settings"
      ),
    ]
  }
}
