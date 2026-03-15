import SwiftUI

struct WidgetView: View {

    let widget: WidgetState

    var body: some View {
        HStack(spacing: 4) {
            if !widget.icon.isEmpty {
                Text(widget.icon)
            }

            if !widget.text.isEmpty {
                Text(widget.text)
            }
        }
        .contentShape(Rectangle())
        .background(
            WidgetMouseView(widgetID: widget.id)
        )
    }
}
