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
                    interactiveContent(sliderView)

                case .progressSlider:
                    interactiveContent(progressSliderView)

                case .progress:
                    interactiveContent(progressView)

                case .sparkline:
                    interactiveContent(sparklineView)

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
                    childRow
                }
            } else {
                maybeOverlayMouse(childRow.modifier(WidgetNodeStyle(node: node)))
            }
        }
    }

    private var itemView: some View {
        let content = HStack(spacing: CGFloat(node.spacing ?? 4)) {
            imageView
            iconText
            labelText
        }
        .modifier(WidgetNodeStyle(node: node))

        return maybeOverlayMouse(content)
    }

    private func nativeCalendarAnchorView<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .foregroundStyle(color(node.color))
            .modifier(WidgetNodeStyle(node: node))
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
                    iconText
                    labelText
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
            iconText
            labelText

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
            iconText
            labelText

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
            iconText
            labelText

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
            iconText
            labelText

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
            return Theme.defaultTextColor
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

    private var childRow: some View {
        HStack(spacing: CGFloat(node.spacing ?? 6)) {
            ForEach(store.children(of: node.id)) { child in
                WidgetNodeView(node: child)
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let imagePath = node.imagePath, !imagePath.isEmpty {
            let customImage = NSImage(contentsOfFile: imagePath)
            let image = customImage ?? NSWorkspace.shared.icon(forFile: imagePath)

            if let tintedImage = tintedImage(from: image, customImage: customImage) {
                Image(nsImage: tintedImage)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .foregroundStyle(color(node.iconColor ?? node.color))
                    .frame(
                        width: CGFloat(node.imageSize ?? 14),
                        height: CGFloat(node.imageSize ?? 14)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: CGFloat(node.imageCornerRadius ?? 4))
                    )
            } else {
                Image(nsImage: image)
                    .renderingMode(.original)
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
        }
    }

    @ViewBuilder
    private var iconText: some View {
        if !node.icon.isEmpty {
            Text(node.icon)
                .font(font(size: node.iconFontSize ?? node.fontSize))
                .foregroundStyle(color(node.iconColor ?? node.color))
        }
    }

    @ViewBuilder
    private var labelText: some View {
        if !node.text.isEmpty {
            Text(node.text)
                .font(font(size: node.labelFontSize ?? node.fontSize))
                .foregroundStyle(color(node.labelColor ?? node.color))
        }
    }

    @ViewBuilder
    private func interactiveContent<Content: View>(_ content: Content) -> some View {
        content
            .modifier(WidgetNodeStyle(node: node))
            .overlay(WidgetMouseView(widgetID: node.root))
    }

    @ViewBuilder
    private func maybeOverlayMouse<Content: View>(_ content: Content) -> some View {
        if node.root == "builtin_calendar" || node.parent != nil {
            content
        } else {
            content
                .overlay(WidgetMouseView(widgetID: node.root))
        }
    }

    private func tintedImage(from image: NSImage, customImage: NSImage?) -> NSImage? {
        guard customImage != nil,
              let tint = node.iconColor ?? node.color,
              !tint.isEmpty else {
            return nil
        }

        let templated = image.copy() as? NSImage ?? image
        templated.isTemplate = true
        return templated
    }
}

private struct WidgetNodeStyle: ViewModifier {

    let node: WidgetNodeState

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
