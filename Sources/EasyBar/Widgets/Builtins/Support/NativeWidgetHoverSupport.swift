/// Display modes that can be mapped to inline label visibility.
protocol InlineLabelDisplayMode {
  var inlineLabelVisibility: InlineLabelVisibility { get }
}

/// Resolved inline label visibility behavior.
enum InlineLabelVisibility {
  case hidden
  case tooltipOnly
  case hover
  case always
}

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
    mode: some InlineLabelDisplayMode,
    isHovered: Bool
  ) -> Bool {
    guard !text.isEmpty else { return false }

    switch mode.inlineLabelVisibility {
    case .hidden, .tooltipOnly:
      return false
    case .hover:
      return isHovered
    case .always:
      return true
    }
  }
}

extension Config.BuiltinBatteryDisplayMode: InlineLabelDisplayMode {
  var inlineLabelVisibility: InlineLabelVisibility {
    switch self {
    case .none:
      return .hidden
    case .tooltip:
      return .tooltipOnly
    case .expand:
      return .hover
    case .always:
      return .always
    }
  }
}

extension Config.BuiltinWiFiDisplayMode: InlineLabelDisplayMode {
  var inlineLabelVisibility: InlineLabelVisibility {
    switch self {
    case .none:
      return .hidden
    case .tooltip:
      return .tooltipOnly
    case .expand:
      return .hover
    case .always:
      return .always
    }
  }
}
