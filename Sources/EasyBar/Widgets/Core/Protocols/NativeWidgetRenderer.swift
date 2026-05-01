import Foundation

protocol NativeWidgetRenderer {
  associatedtype Snapshot
  /// Creates nodes.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState]
}
