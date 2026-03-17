import SwiftUI

struct WidgetBar: View {

    @ObservedObject private var store = WidgetStore.shared
    let position: WidgetPosition

    var body: some View {
        HStack(spacing: 10) {
            ForEach(store.topLevelNodes(for: position)) { node in
                WidgetNodeView(node: node)
            }
        }
    }
}
