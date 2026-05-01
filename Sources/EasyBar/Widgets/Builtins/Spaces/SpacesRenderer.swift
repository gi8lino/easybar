struct SpacesRenderer: NativeWidgetRenderer {

  typealias Snapshot = Config.SpacesBuiltinConfig

  let rootID: String

  /// Creates nodes.
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
