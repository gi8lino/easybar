import SwiftUI

struct WidgetNodeView: View {

    let node: WidgetNodeState

    @ObservedObject private var store = WidgetStore.shared
    @State private var popupPresented = false

    var body: some View {
        Group {
            if !node.visible {
                EmptyView()
            } else {
                switch node.kind {
                case "row", "group":
                    HStack(spacing: CGFloat(node.spacing ?? 6)) {
                        ForEach(store.children(of: node.id)) { child in
                            WidgetNodeView(node: child)
                        }
                    }
                    .modifier(WidgetNodeStyle(node: node))

                case "column":
                    VStack(alignment: .leading, spacing: CGFloat(node.spacing ?? 6)) {
                        ForEach(store.children(of: node.id)) { child in
                            WidgetNodeView(node: child)
                        }
                    }
                    .modifier(WidgetNodeStyle(node: node))

                case "popup":
                    popupAnchor

                default:
                    itemView
                }
            }
        }
    }

    private var itemView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 4)) {
            if !node.icon.isEmpty {
                Text(node.icon)
            }

            if !node.text.isEmpty {
                Text(node.text)
            }
        }
        .foregroundStyle(color(node.color))
        .modifier(WidgetNodeStyle(node: node))
        .background(
            WidgetMouseView(widgetID: node.id)
        )
    }

    private var popupAnchor: some View {
        HStack(spacing: CGFloat(node.spacing ?? 4)) {
            if !node.icon.isEmpty {
                Text(node.icon)
            }

            if !node.text.isEmpty {
                Text(node.text)
            }
        }
        .foregroundStyle(color(node.color))
        .modifier(WidgetNodeStyle(node: node))
        .background(
            WidgetMouseView(widgetID: node.id)
        )
        .onHover { hovering in
            popupPresented = hovering
        }
        .onTapGesture {
            popupPresented.toggle()
        }
        .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
            popupContent
                .padding(8)
        }
    }

    private var popupContent: some View {
        VStack(alignment: .leading, spacing: CGFloat(node.spacing ?? 6)) {
            ForEach(store.children(of: node.id)) { child in
                WidgetNodeView(node: child)
            }
        }
        .modifier(WidgetNodeStyle(node: node))
    }

    private func color(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else {
            return Theme.textColor
        }

        return Color(hex: hex)
    }
}

private struct WidgetNodeStyle: ViewModifier {

    let node: WidgetNodeState

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CGFloat(node.paddingX ?? 0))
            .padding(.vertical, CGFloat(node.paddingY ?? 0))
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat(node.cornerRadius ?? 0))
                    .stroke(
                        borderColor,
                        lineWidth: CGFloat(node.borderWidth ?? 0)
                    )
            }
            .clipShape(
                RoundedRectangle(cornerRadius: CGFloat(node.cornerRadius ?? 0))
            )
            .opacity(node.opacity ?? 1.0)
    }

    private var backgroundColor: Color {
        guard let background = node.backgroundColor, !background.isEmpty else {
            return Color.clear
        }

        return Color(hex: background)
    }

    private var borderColor: Color {
        guard let border = node.borderColor, !border.isEmpty else {
            return Color.clear
        }

        return Color(hex: border)
    }
}
