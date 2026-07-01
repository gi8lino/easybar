import EasyBarShared
import SwiftUI

struct WidgetBar: View {

  @EnvironmentObject private var store: WidgetStore
  let position: WidgetPosition
  let logger: ProcessLogger

  var body: some View {
    HStack(spacing: 4) {
      ForEach(topLevelNodes) { node in
        WidgetNodeView(node: node, logger: logger)
      }
    }
  }

  private var topLevelNodes: [WidgetNodeState] {
    return store.topLevelNodes(for: position)
  }
}
