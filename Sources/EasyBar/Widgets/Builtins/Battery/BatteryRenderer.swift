import Foundation

/// Renders the native battery widget tree from a battery snapshot.
struct BatteryRenderer: NativeWidgetRenderer {

  typealias Snapshot = BatteryNativeWidget.Snapshot

  let rootID: String

  /// Builds the battery nodes for the current snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    switch snapshot.config.displayMode {
    case .tooltip:
      return makeTooltipNodes(snapshot: snapshot)
    case .none, .expand, .always:
      return makeInlineNodes(snapshot: snapshot)
    }
  }
}

// MARK: - Inline Layout

extension BatteryRenderer {

  /// Builds the inline battery layout.
  private func makeInlineNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config

    return [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: snapshot.placement.position,
        order: 0,
        icon: resolvedBatteryIcon(
          for: snapshot.percentage,
          charging: snapshot.charging,
          unavailable: snapshot.isUnavailable,
          fallbackIcon: snapshot.style.icon
        ),
        color: snapshot.colorHex,
        fontSize: config.iconSize
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_label",
        position: snapshot.placement.position,
        order: 1,
        text: snapshot.showLabel ? snapshot.text : "",
        color: snapshot.colorHex,
        visible: snapshot.showLabel && !snapshot.text.isEmpty,
        spacing: 4
      ),
    ]
  }
}

// MARK: - Tooltip Layout

extension BatteryRenderer {

  /// Builds the tooltip popup layout.
  private func makeTooltipNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let popup = snapshot.config.popup

    return [
      BuiltinNativeNodeFactory.makePopupRootNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style
      ),

      BuiltinNativeNodeFactory.makePopupAnchorRowNode(
        rootID: rootID,
        anchorID: "\(rootID)_anchor",
        position: snapshot.placement.position,
        spacing: snapshot.style.spacing
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_anchor",
        childID: "\(rootID)_icon",
        position: snapshot.placement.position,
        order: 0,
        icon: resolvedBatteryIcon(
          for: snapshot.percentage,
          charging: snapshot.charging,
          unavailable: snapshot.isUnavailable,
          fallbackIcon: snapshot.style.icon
        ),
        color: snapshot.colorHex,
        fontSize: snapshot.config.iconSize
      ),

      BuiltinNativeNodeFactory.makeSpacerNode(
        rootID: rootID,
        spacerID: "\(rootID)_popup_spacer",
        parentID: rootID,
        position: snapshot.placement.position,
        order: 1,
        visible: false,
        paddingX: popup.marginX,
        paddingY: popup.marginY,
        opacity: 1
      ),

      BuiltinNativeNodeFactory.makePopupContentColumnNode(
        rootID: rootID,
        contentID: "\(rootID)_popup",
        position: snapshot.placement.position,
        order: 0,
        visible: !snapshot.text.isEmpty,
        paddingX: popup.paddingX,
        paddingY: popup.paddingY,
        spacing: 4,
        backgroundColor: popup.backgroundColorHex,
        borderColor: popup.borderColorHex,
        borderWidth: popup.borderWidth,
        cornerRadius: popup.cornerRadius,
        opacity: 1
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_popup",
        childID: "\(rootID)_popup_text",
        position: snapshot.placement.position,
        order: 0,
        text: snapshot.text,
        color: popup.textColorHex ?? snapshot.colorHex ?? snapshot.style.textColorHex,
        visible: !snapshot.text.isEmpty
      ),
    ]
  }
}

// MARK: - Icon Logic

extension BatteryRenderer {

  /// Resolves the icon for the current battery state.
  fileprivate func resolvedBatteryIcon(
    for percentage: Int,
    charging: Bool,
    unavailable: Bool,
    fallbackIcon: String
  ) -> String {
    if unavailable {
      return fallbackIcon
    }

    if charging {
      switch percentage {
      case 100: return "󰂅"
      case 90...99: return "󰂋"
      case 80...89: return "󰂊"
      case 70...79: return "󰢞"
      case 60...69: return "󰂉"
      case 50...59: return "󰢝"
      case 40...49: return "󰂈"
      case 30...39: return "󰂇"
      case 20...29: return "󰂆"
      case 10...19: return "󰢜"
      default: return "󰂃"
      }
    }

    switch percentage {
    case 100: return "󰁹"
    case 90...99: return "󰂂"
    case 80...89: return "󰂁"
    case 70...79: return "󰂀"
    case 60...69: return "󰁿"
    case 50...59: return "󰁾"
    case 40...49: return "󰁽"
    case 30...39: return "󰁼"
    case 20...29: return "󰁻"
    case 10...19: return "󰁺"
    default: return "󰂃"
    }
  }
}
