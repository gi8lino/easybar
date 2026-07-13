import Foundation

/// Publishes config-defined native groups into a widget store.
@MainActor
final class NativeGroupRegistry {
  private var publishedRootIDs: [String] = []
  private let widgetStore: WidgetStore

  init(widgetStore: WidgetStore) {
    self.widgetStore = widgetStore
  }

  /// Rebuilds all native groups from the provided config snapshot.
  func reload(groups: [Config.BuiltinGroupConfig]) {
    clear()

    for group in groups {
      widgetStore.apply(owner: .native(root: group.id), nodes: [makeNode(group)])
      publishedRootIDs.append(group.id)
    }
  }

  /// Clears all previously published native groups.
  func clear() {
    for rootID in publishedRootIDs {
      widgetStore.apply(owner: .native(root: rootID), nodes: [])
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
