import Foundation

protocol NativeWidgetRenderer {
  associatedtype Snapshot
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState]
}
