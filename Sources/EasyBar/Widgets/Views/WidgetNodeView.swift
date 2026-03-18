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
                case .row, .group:
                    rowOrGroupView

                case .column:
                    VStack(alignment: .leading, spacing: CGFloat(node.spacing ?? 6)) {
                        ForEach(store.children(of: node.id)) { child in
                            WidgetNodeView(node: child)
                        }
                    }
                    .modifier(WidgetNodeStyle(node: node))

                case .spaces:
                    SpacesWidgetView()
                        .modifier(WidgetNodeStyle(node: node))

                case .popup:
                    popupAnchor

                case .slider:
                    sliderView
                        .modifier(WidgetNodeStyle(node: node))
                        .overlay(WidgetMouseView(widgetID: node.root))

                case .progressSlider:
                    progressSliderView
                        .modifier(WidgetNodeStyle(node: node))
                        .overlay(WidgetMouseView(widgetID: node.root))

                case .progress:
                    progressView
                        .modifier(WidgetNodeStyle(node: node))
                        .overlay(WidgetMouseView(widgetID: node.root))

                case .sparkline:
                    sparklineView
                        .modifier(WidgetNodeStyle(node: node))
                        .overlay(WidgetMouseView(widgetID: node.root))

                case .item:
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
                    .font(font(size: node.iconFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.iconColor ?? node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .font(font(size: node.labelFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.labelColor ?? node.color))
            }
        }
        .modifier(WidgetNodeStyle(node: node))

        return Group {
            if node.root == "builtin_calendar" {
                content
            } else {
                content
                    .overlay(WidgetMouseView(widgetID: node.root))
            }
        }
    }

    private func nativeCalendarAnchorView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .foregroundStyle(color(node.color))
            .modifier(WidgetNodeStyle(node: node))
            .overlay(
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
        .overlay(
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
                    .font(font(size: node.iconFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.iconColor ?? node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .font(font(size: node.labelFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.labelColor ?? node.color))
            }

            SliderWidgetView(
                rootWidgetID: node.root,
                minValue: node.min ?? 0,
                maxValue: node.max ?? 100,
                step: node.step ?? 1,
                value: node.value ?? 0,
                tint: color(node.color),
                width: cgFloat(node.width)
            )
        }
    }

    private var progressSliderView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .font(font(size: node.iconFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.iconColor ?? node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .font(font(size: node.labelFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.labelColor ?? node.color))
            }

            ProgressSliderWidgetView(
                rootWidgetID: node.root,
                minValue: node.min ?? 0,
                maxValue: node.max ?? 100,
                step: node.step ?? 1,
                value: node.value ?? 0,
                tint: color(node.color),
                width: cgFloat(node.width)
            )
        }
    }

    private var progressView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .font(font(size: node.iconFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.iconColor ?? node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .font(font(size: node.labelFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.labelColor ?? node.color))
            }

            ProgressBarCanvas(
                value: node.value ?? 0,
                minValue: node.min ?? 0,
                maxValue: node.max ?? 100,
                tint: color(node.color)
            )
            .frame(width: CGFloat(node.width ?? 64), height: CGFloat(node.height ?? 8))
        }
    }

    private var sparklineView: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            if !node.icon.isEmpty {
                Text(node.icon)
                    .font(font(size: node.iconFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.iconColor ?? node.color))
            }

            if !node.text.isEmpty {
                Text(node.text)
                    .font(font(size: node.labelFontSize ?? node.fontSize))
                    .foregroundStyle(color(node.labelColor ?? node.color))
            }

            SparklineCanvas(
                values: node.values ?? [],
                tint: color(node.color),
                lineWidth: CGFloat(node.lineWidth ?? 1.5)
            )
            .frame(width: CGFloat(node.width ?? 64), height: CGFloat(node.height ?? 18))
        }
    }

    private func color(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else {
            return Theme.textColor
        }

        return Color(hex: hex)
    }

    private func font(size: Double?) -> Font? {
        guard let size else { return nil }
        return .system(size: CGFloat(size))
    }

    private func cgFloat(_ value: Double?) -> CGFloat? {
        guard let value else { return nil }
        return CGFloat(value)
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

    /// Splits the layout values out first.
    /// This avoids the SwiftUI type-checker issue from the chained optional math.
    func body(content: Content) -> some View {
        let leading = CGFloat(node.paddingLeft ?? node.paddingX ?? 0)
        let trailing = CGFloat(node.paddingRight ?? node.paddingX ?? 0)
        let top = CGFloat(node.paddingTop ?? node.paddingY ?? 0)
        let bottom = CGFloat(node.paddingBottom ?? node.paddingY ?? 0)
        let frameWidth = node.width.map { CGFloat($0) }
        let frameHeight = node.height.map { CGFloat($0) }
        let radius = CGFloat(node.cornerRadius ?? 0)
        let lineWidth = CGFloat(node.borderWidth ?? 0)
        let yOffset = CGFloat(node.yOffset ?? 0)

        return content
            .padding(.leading, leading)
            .padding(.trailing, trailing)
            .padding(.top, top)
            .padding(.bottom, bottom)
            .frame(
                width: frameWidth,
                height: frameHeight,
                alignment: .center
            )
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        borderColor,
                        lineWidth: lineWidth
                    )
            }
            .clipShape(
                RoundedRectangle(cornerRadius: radius)
            )
            .opacity(node.opacity ?? 1.0)
            .offset(y: yOffset)
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
