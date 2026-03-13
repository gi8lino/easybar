import SwiftUI

struct WidgetBar: View {

    @ObservedObject private var store = WidgetStore.shared
    let position: String

    var body: some View {
        HStack(spacing: 10) {
            ForEach(store.widgets.filter { $0.position == position }) { widget in
                WidgetView(widget: widget)
            }
        }
    }
}
