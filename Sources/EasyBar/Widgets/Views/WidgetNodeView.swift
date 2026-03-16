import SwiftUI
import AppKit

struct WidgetNodeView: View {

    let node: WidgetNodeState

    @ObservedObject private var store = WidgetStore.shared

    @State private var popupPresented = false
    @State private var anchorHovered = false
    @State private var popupHovered = false

    var body: some View {
        Group {
            if !node.visible {
                EmptyView()
            } else {
                switch node.kind {
                case "row", "group":
                    rowOrGroupView

                case "column":
                    VStack(alignment: .leading, spacing: CGFloat(node.spacing ?? 6)) {
                        ForEach(store.children(of: node.id)) { child in
                            WidgetNodeView(node: child)
                        }
                    }
                    .modifier(WidgetNodeStyle(node: node))

                case "spaces":
                    SpacesWidgetView()
                        .modifier(WidgetNodeStyle(node: node))

                case "popup":
                    popupAnchor

                case "slider":
                    sliderView
                        .modifier(WidgetNodeStyle(node: node))
                        .background(WidgetMouseView(widgetID: node.root))

                case "progress_slider":
                    progressSliderView
                        .modifier(WidgetNodeStyle(node: node))
                        .background(WidgetMouseView(widgetID: node.root))

                case "progress":
                    progressView
                        .modifier(WidgetNodeStyle(node: node))
                        .background(WidgetMouseView(widgetID: node.root))

                case "sparkline":
                    sparklineView
                        .modifier(WidgetNodeStyle(node: node))
                        .background(WidgetMouseView(widgetID: node.root))

                default:
                    itemView
                }
            }
        }
    }

    private var rowOrGroupView: some View {
        Group {
            if node.id == "builtin_calendar" {
                nativeCalendarAnchorView {
                    HStack(spacing: CGFloat(node.spacing ?? 6)) {
                        ForEach(store.children(of: node.id)) { child in
                            WidgetNodeView(node: child)
                        }
                    }
                }
            } else {
                HStack(spacing: CGFloat(node.spacing ?? 6)) {
                    ForEach(store.children(of: node.id)) { child in
                        WidgetNodeView(node: child)
                    }
                }
                .modifier(WidgetNodeStyle(node: node))
            }
        }
    }

    private var itemView: some View {
        let content = HStack(spacing: CGFloat(node.spacing ?? 4)) {
            if let imagePath = node.imagePath, !imagePath.isEmpty {
                Image(nsImage: NSWorkspace.shared.icon(forFile: imagePath))
                    .resizable()
                    .interpolation(.high)
                    .frame(
                        width: CGFloat(node.imageSize ?? 14),
                        height: CGFloat(node.imageSize ?? 14)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: CGFloat(node.imageCornerRadius ?? 4))
                    )
            }

            if !node.icon.isEmpty {
                Text(node.icon)
            }

            if !node.text.isEmpty {
                Text(node.text)
            }
        }
        .foregroundStyle(color(node.color))
        .modifier(WidgetNodeStyle(node: node))

        return Group {
            if node.root == "builtin_calendar" {
                content
            } else {
                content
                    .background(WidgetMouseView(widgetID: node.root))
            }
        }
    }

    private func nativeCalendarAnchorView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .foregroundStyle(color(node.color))
            .modifier(WidgetNodeStyle(node: node))
            .background(
                WidgetMouseView(widgetID: node.root)
            )
            .onHover { hovering in
                anchorHovered = hovering

                if hovering {
                    popupPresented = true
                } else {
                    schedulePopupCloseCheck()
                }
            }
            .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
                NativeCalendarPopupView()
                    .padding(8)
                    .background(
                        PopupHoverRegion { hovering in
                            popupHovered = hovering

                            if !hovering {
                                schedulePopupCloseCheck()
                            }
                        }
                    )
            }
    }

    private var popupAnchor: some View {
        Group {
            if store.anchorChildren(of: node.id).isEmpty {
                HStack(spacing: CGFloat(node.spacing ?? 4)) {
                    if !node.icon.isEmpty {
                        Text(node.icon)
                    }

                    if !node.text.isEmpty {
                        Text(node.text)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: CGFloat(node.spacing ?? 4)) {
                    ForEach(store.anchorChildren(of: node.id)) { child in
                        WidgetNodeView(node: child)
                    }
                }
            }
        }
        .foregroundStyle(color(node.color))
        .modifier(WidgetNodeStyle(node: node))
        .background(
            WidgetMouseView(widgetID: node.root)
        )
        .onHover { hovering in
            anchorHovered = hovering

            if hovering {
                popupPresented = true
            } else {
                schedulePopupCloseCheck()
            }
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
        .background(
            PopupHoverRegion { hovering in
                popupHovered = hovering

                if !hovering {
                    schedulePopupCloseCheck()
                }
            }
        )
    }

    private var sliderView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .foregroundStyle(color(node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .foregroundStyle(color(node.color))
            }

            SliderWidgetView(
                rootWidgetID: node.root,
                minValue: node.min ?? 0,
                maxValue: node.max ?? 100,
                step: node.step ?? 1,
                value: node.value ?? 0,
                tint: color(node.color)
            )
        }
    }

    private var progressSliderView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .foregroundStyle(color(node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .foregroundStyle(color(node.color))
            }

            ProgressSliderWidgetView(
                rootWidgetID: node.root,
                minValue: node.min ?? 0,
                maxValue: node.max ?? 100,
                step: node.step ?? 1,
                value: node.value ?? 0,
                tint: color(node.color)
            )
        }
    }

    private var progressView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .foregroundStyle(color(node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .foregroundStyle(color(node.color))
            }

            ProgressBarCanvas(
                value: node.value ?? 0,
                minValue: node.min ?? 0,
                maxValue: node.max ?? 100,
                tint: color(node.color)
            )
            .frame(width: 64, height: 8)
        }
    }

    private var sparklineView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .foregroundStyle(color(node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .foregroundStyle(color(node.color))
            }

            SparklineCanvas(
                values: node.values ?? [],
                tint: color(node.color),
                lineWidth: CGFloat(node.lineWidth ?? 1.5)
            )
            .frame(width: 64, height: 18)
        }
    }

    private func color(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else {
            return Theme.textColor
        }

        return Color(hex: hex)
    }

    private func schedulePopupCloseCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if !anchorHovered && !popupHovered {
                popupPresented = false
            }
        }
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
