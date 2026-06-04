import EasyBarShared
import SwiftUI

/// Recursive SwiftUI renderer for one widget node.
struct WidgetNodeView: View {
  let node: WidgetNodeState
  let logger: ProcessLogger

  @ObservedObject var store = WidgetStore.shared
  @EnvironmentObject var configStore: ConfigSnapshotStore

  @StateObject var popupPanel = WidgetPopupPanelController()
  @State var popupPresented = false
  @State var anchorHovered = false
  @State var popupHovered = false

  var body: some View {
    Group {
      if node.visible {
        renderedNodeView
      } else {
        EmptyView()
      }
    }
    .onChange(of: popupPresented, initial: true) { _, presented in
      updatePopupPanel(isPresented: presented)
    }
    .onDisappear {
      popupPanel.close()
    }
  }
}
