import Foundation

/// Renders the native Wi-Fi widget tree from a Wi-Fi snapshot.
struct WiFiRenderer: NativeWidgetRenderer {

  typealias Snapshot = WiFiNativeWidget.Snapshot

  let rootID: String

  /// Builds the Wi-Fi nodes for the current snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
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
}
