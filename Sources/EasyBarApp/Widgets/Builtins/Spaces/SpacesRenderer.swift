/// Renders the native spaces widget root.
struct SpacesRenderer {

  let rootID: String

  /// Builds the native spaces node for the current config.
  func makeNodes(snapshot: Config.SpacesBuiltinConfig) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeSpacesNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style
      )
    ]
  }
}
