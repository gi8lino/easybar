import EasyBarShared
import SwiftUI

struct WidgetBar: View {

  @ObservedObject private var store = WidgetStore.shared
  let position: WidgetPosition
  let logger: ProcessLogger

  /// Renders the widgets for one bar position.
  var body: some View {
    HStack(spacing: 4) {
      ForEach(topLevelNodes) { node in
        WidgetNodeView(node: node, logger: logger)
      }
    }
  }

  /// Returns the rendered top-level nodes for this bar position.
  private var topLevelNodes: [WidgetNodeState] {
    return store.topLevelNodes(for: position)
  }
}
