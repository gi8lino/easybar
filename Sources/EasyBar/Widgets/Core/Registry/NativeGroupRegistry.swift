import Foundation

/// Publishes config-defined native groups into the shared widget store.
final class NativeGroupRegistry {

  static let shared = NativeGroupRegistry()

  private var publishedRootIDs: [String] = []

  private init() {}

  /// Rebuilds all native groups from the current config.
  func reload() {
    clear()

    for group in Config.shared.builtinGroups {
      WidgetStore.shared.apply(root: group.id, nodes: [makeNode(group)])
      publishedRootIDs.append(group.id)
    }
  }

  /// Clears all previously published native groups.
  func clear() {
    for rootID in publishedRootIDs {
      WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    publishedRootIDs.removeAll()
  }

  /// Builds one native group root node.
  private func makeNode(_ group: Config.BuiltinGroupConfig) -> WidgetNodeState {
    BuiltinNativeNodeFactory.makeGroupNode(
      id: group.id,
      placement: group.placement,
      style: group.style
    )
  }
}
