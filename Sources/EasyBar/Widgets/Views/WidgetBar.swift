import SwiftUI

struct WidgetBar: View {

  @ObservedObject private var store = WidgetStore.shared
  let position: WidgetPosition

  var body: some View {
    HStack(spacing: 10) {
      ForEach(topLevelNodes) { node in
        WidgetNodeView(node: node)
      }
    }
  }

  /// Returns the rendered top-level nodes for this bar position.
  private var topLevelNodes: [WidgetNodeState] {
    store.topLevelNodes(for: position)
  }
}
