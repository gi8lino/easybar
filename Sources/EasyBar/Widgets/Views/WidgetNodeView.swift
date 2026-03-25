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
                if node.kind.isRowLikeContainer {
                    rowOrGroupView
                } else {
                    switch node.kind {
                    case .column:
                    VStack(alignment: .leading, spacing: stackSpacing) {
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
                    case .row, .group:
                        EmptyView()
                    }
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
        let content = HStack(spacing: itemSpacing) {
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
            .onHover { hovering in handleAnchorHover(hovering) }
            .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
                NativeCalendarPopupView()
                    .background(popupHoverBackground)
            }
    }

    private var popupAnchor: some View {
        Group {
            if !hasAnchorChildren {
                HStack(spacing: itemSpacing) {
                    iconText
                    labelText
                }
            } else {
                VStack(alignment: .leading, spacing: itemSpacing) {
                    ForEach(anchorChildren) { child in
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
        .onHover { hovering in handleAnchorHover(hovering) }
        .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
            popupContent
        }
    }

    private var popupContent: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            ForEach(children) { child in
                WidgetNodeView(node: child)
            }
        }
        .modifier(WidgetNodeStyle(node: node))
        .background(popupHoverBackground)
    }

    private var sliderView: some View {
        HStack(spacing: stackSpacing) {
            iconText
            labelText

            SliderWidgetView(
                rootWidgetID: node.root,
                minValue: minValue,
                maxValue: maxValue,
                step: stepValue,
                value: currentValue,
                tint: nodeColor,
                width: nodeWidth
            )
        }
    }

    private var progressSliderView: some View {
        HStack(spacing: stackSpacing) {
            iconText
            labelText

            ProgressSliderWidgetView(
                rootWidgetID: node.root,
                minValue: minValue,
                maxValue: maxValue,
                step: stepValue,
                value: currentValue,
                tint: nodeColor,
                width: nodeWidth
            )
        }
    }

    private var progressView: some View {
        HStack(spacing: stackSpacing) {
            iconText
            labelText

            ProgressBarCanvas(
                value: currentValue,
                minValue: minValue,
                maxValue: maxValue,
                tint: nodeColor
            )
            .frame(width: progressWidth, height: progressHeight)
        }
    }

    private var sparklineView: some View {
        HStack(spacing: stackSpacing) {
            iconText
            labelText

            SparklineCanvas(
                values: node.values ?? [],
                tint: nodeColor,
                lineWidth: sparklineLineWidth
            )
            .frame(width: sparklineWidth, height: sparklineHeight)
        }
    }

    /// Returns the resolved node color.
    private var nodeColor: Color {
        color(node.color)
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
            closePopupIfIdle()
        }
    }

    /// Handles hover changes on the popup anchor.
    private func handleAnchorHover(_ hovering: Bool) {
        anchorHovered = hovering

        if hovering {
            popupPresented = true
            return
        }

        schedulePopupCloseCheck()
    }

    /// Handles hover changes on the popup content.
    private func handlePopupHover(_ hovering: Bool) {
        popupHovered = hovering

        guard !hovering else { return }
        schedulePopupCloseCheck()
    }

    /// Closes the popup when neither anchor nor popup is hovered.
    private func closePopupIfIdle() {
        guard !anchorHovered else { return }
        guard !popupHovered else { return }
        popupPresented = false
    }

    private var childRow: some View {
        HStack(spacing: stackSpacing) {
            ForEach(children) { child in
                WidgetNodeView(node: child)
            }
        }
    }

    /// Returns the default stack spacing for this node.
    private var stackSpacing: CGFloat {
        CGFloat(node.spacing ?? 6)
    }

    /// Returns the default item spacing for this node.
    private var itemSpacing: CGFloat {
        CGFloat(node.spacing ?? 4)
    }

    /// Returns the current scalar value.
    private var currentValue: Double {
        node.value ?? 0
    }

    /// Returns the minimum scalar value.
    private var minValue: Double {
        node.min ?? 0
    }

    /// Returns the maximum scalar value.
    private var maxValue: Double {
        node.max ?? 100
    }

    /// Returns the slider step value.
    private var stepValue: Double {
        node.step ?? 1
    }

    /// Returns the progress width.
    private var progressWidth: CGFloat {
        CGFloat(node.width ?? 64)
    }

    /// Returns the progress height.
    private var progressHeight: CGFloat {
        CGFloat(node.height ?? 8)
    }

    /// Returns the sparkline width.
    private var sparklineWidth: CGFloat {
        CGFloat(node.width ?? 64)
    }

    /// Returns the sparkline height.
    private var sparklineHeight: CGFloat {
        CGFloat(node.height ?? 18)
    }

    /// Returns the sparkline line width.
    private var sparklineLineWidth: CGFloat {
        CGFloat(node.lineWidth ?? 1.5)
    }

    /// Returns the converted node width when present.
    private var nodeWidth: CGFloat? {
        cgFloat(node.width)
    }

    /// Returns the non-anchor children for this node.
    private var children: [WidgetNodeState] {
        store.children(of: node.id)
    }

    /// Returns the popup anchor children for this node.
    private var anchorChildren: [WidgetNodeState] {
        store.anchorChildren(of: node.id)
    }

    /// Returns whether this node has popup anchor children.
    private var hasAnchorChildren: Bool {
        !anchorChildren.isEmpty
    }

    /// Returns the shared popup hover region.
    private var popupHoverBackground: some View {
        PopupHoverRegion { hovering in handlePopupHover(hovering) }
    }

    /// Returns whether the root mouse overlay should be skipped.
    private var shouldSkipMouseOverlay: Bool {
        node.root == "builtin_calendar" || node.hasParent
    }

    /// Returns the resolved icon color.
    private var iconResolvedColor: Color {
        color(node.iconColor ?? node.color)
    }

    /// Returns the resolved label color.
    private var labelResolvedColor: Color {
        color(node.labelColor ?? node.color)
    }

    /// Returns the resolved icon font.
    private var iconResolvedFont: Font? {
        font(size: node.iconFontSize ?? node.fontSize)
    }

    /// Returns the resolved label font.
    private var labelResolvedFont: Font? {
        font(size: node.labelFontSize ?? node.fontSize)
    }

    @ViewBuilder
    private var imageView: some View {
        if let imagePath = node.imagePath, !imagePath.isEmpty {
            let customImage = NSImage(contentsOfFile: imagePath)
            let image = resolvedImage(imagePath: imagePath, customImage: customImage)

            if let tintedImage = tintedImage(from: image, customImage: customImage) {
                imageBaseView(image: tintedImage, renderingMode: .template)
                    .foregroundStyle(iconResolvedColor)
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
            } else {
                imageBaseView(image: image, renderingMode: .original)
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
            }
        }
    }

    @ViewBuilder
    private var iconText: some View {
        if !node.icon.isEmpty {
            Text(node.icon)
                .font(iconResolvedFont)
                .foregroundStyle(iconResolvedColor)
        }
    }

    @ViewBuilder
    private var labelText: some View {
        if !node.text.isEmpty {
            Text(node.text)
                .font(labelResolvedFont)
                .foregroundStyle(labelResolvedColor)
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
        if shouldSkipMouseOverlay {
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

    /// Returns the rendered image size.
    private var imageSize: CGFloat {
        CGFloat(node.imageSize ?? 14)
    }

    /// Returns the rendered image corner radius.
    private var imageCornerRadius: CGFloat {
        CGFloat(node.imageCornerRadius ?? 4)
    }

    /// Resolves the image file or falls back to the file icon.
    private func resolvedImage(imagePath: String, customImage: NSImage?) -> NSImage {
        customImage ?? NSWorkspace.shared.icon(forFile: imagePath)
    }

    /// Builds the shared base image view.
    private func imageBaseView(
        image: NSImage,
        renderingMode: Image.TemplateRenderingMode
    ) -> some View {
        Image(nsImage: image)
            .renderingMode(renderingMode)
            .resizable()
            .interpolation(.high)
    }
}

private struct WidgetNodeStyle: ViewModifier {

    let node: WidgetNodeState

    func body(content: Content) -> some View {
        return content
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(
                width: frameWidth,
                height: frameHeight,
                alignment: .center
            )
            .background(backgroundColor)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderColor,
                        lineWidth: borderWidth
                    )
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius)
            )
            .opacity(node.opacity ?? 1.0)
            .offset(y: verticalOffset)
    }

    /// Returns the resolved leading padding.
    private var leadingPadding: CGFloat {
        CGFloat(node.paddingLeft ?? node.paddingX ?? 0)
    }

    /// Returns the resolved trailing padding.
    private var trailingPadding: CGFloat {
        CGFloat(node.paddingRight ?? node.paddingX ?? 0)
    }

    /// Returns the resolved top padding.
    private var topPadding: CGFloat {
        CGFloat(node.paddingTop ?? node.paddingY ?? 0)
    }

    /// Returns the resolved bottom padding.
    private var bottomPadding: CGFloat {
        CGFloat(node.paddingBottom ?? node.paddingY ?? 0)
    }

    /// Returns the resolved frame width.
    private var frameWidth: CGFloat? {
        node.width.map(CGFloat.init)
    }

    /// Returns the resolved frame height.
    private var frameHeight: CGFloat? {
        node.height.map(CGFloat.init)
    }

    /// Returns the resolved node corner radius.
    private var cornerRadius: CGFloat {
        CGFloat(node.cornerRadius ?? 0)
    }

    /// Returns the resolved node border width.
    private var borderWidth: CGFloat {
        CGFloat(node.borderWidth ?? 0)
    }

    /// Returns the resolved vertical offset.
    private var verticalOffset: CGFloat {
        CGFloat(node.yOffset ?? 0)
    }

    private var backgroundColor: Color {
        resolvedColor(node.backgroundColor)
    }

    private var borderColor: Color {
        resolvedColor(node.borderColor)
    }

    /// Resolves one optional node color or clears it.
    private func resolvedColor(_ hex: String?) -> Color {
        guard let hex, !hex.isEmpty else { return Color.clear }
        return Color(hex: hex)
    }
}
