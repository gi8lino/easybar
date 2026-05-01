/// Renders the native spaces widget root.
struct SpacesRenderer: NativeWidgetRenderer {

  typealias Snapshot = Config.SpacesBuiltinConfig

  let rootID: String

  /// Builds the native spaces node for the current config.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeSpacesNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style
      )
    ]
  }
}
