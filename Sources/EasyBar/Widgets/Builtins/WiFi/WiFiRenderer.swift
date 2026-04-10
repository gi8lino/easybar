import Foundation

/// Renders the native Wi-Fi widget tree from a Wi-Fi snapshot.
struct WiFiRenderer: NativeWidgetRenderer {

  typealias Snapshot = WiFiNativeWidget.Snapshot

  let rootID: String

  /// Builds the Wi-Fi nodes for the current snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    switch snapshot.config.displayMode {
    case .tooltip:
      return makeTooltipNodes(snapshot: snapshot)
    case .none, .expand, .always:
      return makeInlineNodes(snapshot: snapshot)
    }
  }
}

extension WiFiRenderer {
  private func makeInlineNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: snapshot.config.placement,
        style: snapshot.config.style
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: snapshot.config.placement.position,
        order: 0,
        icon: snapshot.iconText,
        color: snapshot.iconColorHex,
        fontSize: 16
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_label",
        position: snapshot.config.placement.position,
        order: 1,
        text: snapshot.labelText,
        color: snapshot.config.textColorHex,
        visible: snapshot.labelVisible,
        spacing: 4
      ),
    ]
  }

  private func makeTooltipNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    let popup = snapshot.config.popup
    var popupNode = BuiltinNativeNodeFactory.makePopupContentColumnNode(
      rootID: rootID,
      contentID: "\(rootID)_popup",
      position: snapshot.config.placement.position,
      order: 0,
      visible: snapshot.popupVisible,
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
        placement: snapshot.config.placement,
        style: snapshot.config.style
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: snapshot.config.placement.position,
        order: 0,
        icon: snapshot.iconText,
        color: snapshot.iconColorHex,
        fontSize: 16
      ),
      popupNode,

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_popup",
        childID: "\(rootID)_popup_text",
        position: snapshot.config.placement.position,
        order: 0,
        text: snapshot.labelText,
        color: popup.textColorHex ?? snapshot.config.textColorHex,
        visible: snapshot.popupVisible
      ),
    ]
  }
}
