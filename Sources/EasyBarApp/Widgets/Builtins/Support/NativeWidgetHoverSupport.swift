/// Shared hover helpers for native widgets with expandable labels.
enum NativeWidgetHoverSupport {
  /// Updates hover state from a widget mouse event.
  static func updateHoverState(_ event: WidgetEvent, isHovered: inout Bool) -> Bool {
    switch event {
    case .mouseEntered:
      guard !isHovered else { return false }
      isHovered = true
      return true

    case .mouseExited:
      guard isHovered else { return false }
      isHovered = false
      return true

    default:
      return false
    }
  }

  /// Returns whether an inline label should be visible.
  static func showsInlineLabel(
    text: String,
    mode: Config.BuiltinBatteryDisplayMode,
    isHovered: Bool
  ) -> Bool {
    guard !text.isEmpty else { return false }

    switch mode {
    case .none, .tooltip:
      return false
    case .expand:
      return isHovered
    case .always:
      return true
    }
  }
}
