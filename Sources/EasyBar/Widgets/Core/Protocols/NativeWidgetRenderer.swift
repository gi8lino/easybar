import Foundation

/// Renders a native widget snapshot into node state.
protocol NativeWidgetRenderer {
  associatedtype Snapshot
  /// Builds node state for one snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState]
}
