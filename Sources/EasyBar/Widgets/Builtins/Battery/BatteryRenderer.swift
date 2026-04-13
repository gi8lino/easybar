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
        icon: snapshot.isUnavailable ? snapshot.style.icon : "",
        color: snapshot.colorHex,
        symbolName: resolvedBatterySymbol(
          for: snapshot.percentage,
          unavailable: snapshot.isUnavailable
        ),
        symbolSecondaryColor: resolvedBatteryFrameColor(snapshot: snapshot),
        symbolOverlayName: resolvedBatteryOverlaySymbol(
          charging: snapshot.charging,
          onExternalPower: snapshot.onExternalPower,
          unavailable: snapshot.isUnavailable
        ),
        symbolOverlayColor: resolvedBatteryOverlayColor(snapshot: snapshot),
        symbolOverlayBackdropColor: resolvedBatteryOverlayBackdropColor(snapshot: snapshot),
        symbolOverlayScale: resolvedBatteryOverlayScale(snapshot: snapshot),
        symbolOverlayBackdropScale: resolvedBatteryOverlayBackdropScale(snapshot: snapshot),
        symbolOverlayOffsetX: resolvedBatteryOverlayOffsetX(snapshot: snapshot),
        symbolOverlayOffsetY: resolvedBatteryOverlayOffsetY(snapshot: snapshot),
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
    var popupNode = BuiltinNativeNodeFactory.makePopupContentColumnNode(
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
    )
    popupNode.marginX = popup.marginX
    popupNode.marginY = popup.marginY

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
        icon: snapshot.isUnavailable ? snapshot.style.icon : "",
        color: snapshot.colorHex,
        symbolName: resolvedBatterySymbol(
          for: snapshot.percentage,
          unavailable: snapshot.isUnavailable
        ),
        symbolSecondaryColor: resolvedBatteryFrameColor(snapshot: snapshot),
        symbolOverlayName: resolvedBatteryOverlaySymbol(
          charging: snapshot.charging,
          onExternalPower: snapshot.onExternalPower,
          unavailable: snapshot.isUnavailable
        ),
        symbolOverlayColor: resolvedBatteryOverlayColor(snapshot: snapshot),
        symbolOverlayBackdropColor: resolvedBatteryOverlayBackdropColor(snapshot: snapshot),
        symbolOverlayScale: resolvedBatteryOverlayScale(snapshot: snapshot),
        symbolOverlayBackdropScale: resolvedBatteryOverlayBackdropScale(snapshot: snapshot),
        symbolOverlayOffsetX: resolvedBatteryOverlayOffsetX(snapshot: snapshot),
        symbolOverlayOffsetY: resolvedBatteryOverlayOffsetY(snapshot: snapshot),
        fontSize: snapshot.config.iconSize
      ),
      popupNode,

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

  /// Resolves the base SF Symbol for the current battery level.
  fileprivate func resolvedBatterySymbol(
    for percentage: Int,
    unavailable: Bool
  ) -> String? {
    if unavailable {
      return nil
    }

    switch percentage {
    case 88...100:
      return "battery.100percent"
    case 63...87:
      return "battery.75percent"
    case 38...62:
      return "battery.50percent"
    case 13...37:
      return "battery.25percent"
    default:
      return "battery.0percent"
    }
  }

  /// Resolves the overlay symbol for charging and plugged-in hold states.
  fileprivate func resolvedBatteryOverlaySymbol(
    charging: Bool,
    onExternalPower: Bool,
    unavailable: Bool
  ) -> String? {
    guard !unavailable else { return nil }

    if charging {
      return "bolt.fill"
    }

    if onExternalPower {
      return "powerplug.portrait"
    }

    return nil
  }

  /// Returns the overlay scale for the charging bolt or external-power plug.
  fileprivate func resolvedBatteryOverlayScale(snapshot: Snapshot) -> Double? {
    if snapshot.charging {
      return 0.48
    }

    if snapshot.onExternalPower {
      return 0.54
    }

    return nil
  }

  /// Returns the backdrop scale used to create a soft outline around the plug.
  fileprivate func resolvedBatteryOverlayBackdropScale(snapshot: Snapshot) -> Double? {
    if snapshot.onExternalPower && !snapshot.charging {
      return 0.62
    }

    return nil
  }

  /// Returns the horizontal overlay offset used to visually center the plug.
  fileprivate func resolvedBatteryOverlayOffsetX(snapshot: Snapshot) -> Double? {
    if snapshot.onExternalPower && !snapshot.charging {
      return -1
    }

    return nil
  }

  /// Returns the vertical overlay offset for the charging bolt or plug.
  fileprivate func resolvedBatteryOverlayOffsetY(snapshot: Snapshot) -> Double? {
    if snapshot.charging {
      return -0.35
    }

    if snapshot.onExternalPower {
      return -0.14
    }

    return nil
  }

  /// Returns the frame color used to visually separate the plug from the battery.
  fileprivate func resolvedBatteryFrameColor(snapshot: Snapshot) -> String? {
    guard !snapshot.isUnavailable else { return nil }
    return snapshot.config.colors.frameColorHex
  }

  // Returns the color of the charging bolt or external-power plug.
  fileprivate func resolvedBatteryOverlayColor(snapshot: Snapshot) -> String? {
    if snapshot.charging {
      return snapshot.config.colors.chargingOverlayColorHex
    }

    if snapshot.onExternalPower {
      return "#FFFFFFFF"
    }

    return nil
  }

  /// Returns the soft translucent border color behind the external-power plug.
  fileprivate func resolvedBatteryOverlayBackdropColor(snapshot: Snapshot) -> String? {
    if snapshot.onExternalPower && !snapshot.charging {
      return "#000000F0"
    }

    return nil
  }
}
