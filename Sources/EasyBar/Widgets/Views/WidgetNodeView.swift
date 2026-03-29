import AppKit
import SwiftUI

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
        renderedNodeView
      }
    }
  }
}

// MARK: - Top-Level Rendering

private extension WidgetNodeView {
  /// Returns the rendered view for the current node kind.
  @ViewBuilder
  var renderedNodeView: some View {
    if node.kind.isRowLikeContainer {
      rowOrGroupView
    } else if node.kind.isCustomRenderedKind {
      customRenderedNodeView
    } else if node.kind.isDedicatedContainerKind {
      dedicatedContainerNodeView
    } else if node.kind.isInteractiveKind {
      interactiveNodeView
    } else if node.kind == .item {
      itemView
    } else {
      EmptyView()
    }
  }

  /// Returns the custom-rendered view for the current node kind.
  @ViewBuilder
  var customRenderedNodeView: some View {
    switch node.kind {
    case .spaces:
      SpacesWidgetView()
        .modifier(nodeStyle)
    default:
      EmptyView()
    }
  }

  /// Returns the dedicated container view for the current node kind.
  @ViewBuilder
  var dedicatedContainerNodeView: some View {
    switch node.kind {
    case .column:
      VStack(alignment: .leading, spacing: stackSpacing) {
        ForEach(children) { child in
          WidgetNodeView(node: child)
        }
      }
      .modifier(nodeStyle)
    case .popup:
      popupAnchor
    default:
      EmptyView()
    }
  }

  /// Returns the interactive view for the current node kind.
  @ViewBuilder
  var interactiveNodeView: some View {
    switch node.kind {
    case .slider:
      styledMouseContent(sliderView)
    case .progressSlider:
      styledMouseContent(progressSliderView)
    case .progress:
      styledMouseContent(progressView)
    case .sparkline:
      styledMouseContent(sparklineView)
    default:
      EmptyView()
    }
  }

  var rowOrGroupView: some View {
    Group {
      if node.isCalendarRoot {
        nativeCalendarAnchorView {
          childRow
        }
      } else if hasPopupChildren {
        popupAnchorSurface(childRow)
      } else {
        styledMouseContent(childRow)
      }
    }
  }

  var itemView: some View {
    if hasPopupChildren {
      return AnyView(popupItemSurface(itemContent))
    }

    return AnyView(styledMouseContent(itemContent))
  }

  func nativeCalendarAnchorView<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .foregroundStyle(nodeColor)
      .modifier(nodeStyle)
      .onHover { hovering in handleAnchorHover(hovering) }
      .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
        NativeCalendarPopupView()
          .background(popupHoverBackground)
      }
  }

  var popupAnchor: some View {
    let content = Group {
      if !hasAnchorChildren {
        itemContent
      } else {
        VStack(alignment: .leading, spacing: itemSpacing) {
          ForEach(anchorChildren) { child in
            WidgetNodeView(node: child)
          }
        }
      }
    }

    return popupAnchorSurface(content)
  }

  var popupContent: some View {
    VStack(alignment: .leading, spacing: stackSpacing) {
      ForEach(popupChildren) { child in
        WidgetNodeView(node: child)
      }
    }
    .fixedSize()
    .modifier(nodeStyle)
  }
}

// MARK: - Node Content

private extension WidgetNodeView {
  /// Returns the row content for a plain item.
  var itemContent: some View {
    HStack(spacing: itemSpacing) {
      imageView
      iconText
      labelText
    }
  }

  /// Returns the slider row for the current node.
  var sliderView: some View {
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

  /// Returns the progress-slider row for the current node.
  var progressSliderView: some View {
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

  /// Returns the progress row for the current node.
  var progressView: some View {
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

  /// Returns the sparkline row for the current node.
  var sparklineView: some View {
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
}

// MARK: - Popup State

private extension WidgetNodeView {
  /// Returns the resolved node color.
  var nodeColor: Color {
    color(node.color)
  }

  /// Resolves one optional hex color.
  func color(_ hex: String?) -> Color {
    guard let hex, !hex.isEmpty else {
      return Theme.defaultTextColor
    }

    return Color(hex: hex)
  }

  /// Converts one optional font size into a SwiftUI font.
  func font(size: Double?) -> Font? {
    guard let size else { return nil }
    return .system(size: CGFloat(size))
  }

  /// Converts one optional scalar into CGFloat.
  func cgFloat(_ value: Double?) -> CGFloat? {
    guard let value else { return nil }
    return CGFloat(value)
  }

  /// Schedules one delayed popup-close check.
  func schedulePopupCloseCheck() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      closePopupIfIdle()
    }
  }

  /// Handles hover changes on the popup anchor.
  func handleAnchorHover(_ hovering: Bool) {
    anchorHovered = hovering
    emitPopupAnchorHoverEvent(hovering)

    if hovering {
      popupPresented = true
      return
    }

    schedulePopupCloseCheck()
  }

  /// Handles hover changes on the popup content.
  func handlePopupHover(_ hovering: Bool) {
    popupHovered = hovering

    guard !hovering else { return }
    schedulePopupCloseCheck()
  }

  /// Closes the popup when neither anchor nor popup is hovered.
  func closePopupIfIdle() {
    guard !anchorHovered else { return }
    guard !popupHovered else { return }
    popupPresented = false
  }

  /// Emits popup anchor hover events without using the AppKit mouse tracker.
  func emitPopupAnchorHoverEvent(_ hovering: Bool) {
    guard node.kind == .popup || hasPopupChildren else { return }

    if hovering {
      EventBus.shared.emitWidgetEvent(
        .mouseEntered,
        widgetID: node.root,
        targetWidgetID: node.id
      )
      return
    }

    EventBus.shared.emitWidgetEvent(
      .mouseExited,
      widgetID: node.root,
      targetWidgetID: node.id
    )
  }
}

// MARK: - Layout Data

private extension WidgetNodeView {
  /// Returns the row of child nodes.
  var childRow: some View {
    HStack(spacing: stackSpacing) {
      ForEach(children) { child in
        WidgetNodeView(node: child)
      }
    }
  }

  /// Returns the default stack spacing for this node.
  var stackSpacing: CGFloat {
    CGFloat(node.spacing ?? 6)
  }

  /// Returns the default item spacing for this node.
  var itemSpacing: CGFloat {
    CGFloat(node.spacing ?? 4)
  }

  /// Returns the current scalar value.
  var currentValue: Double {
    node.value ?? 0
  }

  /// Returns the minimum scalar value.
  var minValue: Double {
    node.min ?? 0
  }

  /// Returns the maximum scalar value.
  var maxValue: Double {
    node.max ?? 100
  }

  /// Returns the slider step value.
  var stepValue: Double {
    node.step ?? 1
  }

  /// Returns the progress width.
  var progressWidth: CGFloat {
    CGFloat(node.width ?? 64)
  }

  /// Returns the progress height.
  var progressHeight: CGFloat {
    CGFloat(node.height ?? 8)
  }

  /// Returns the sparkline width.
  var sparklineWidth: CGFloat {
    CGFloat(node.width ?? 64)
  }

  /// Returns the sparkline height.
  var sparklineHeight: CGFloat {
    CGFloat(node.height ?? 18)
  }

  /// Returns the sparkline line width.
  var sparklineLineWidth: CGFloat {
    CGFloat(node.lineWidth ?? 1.5)
  }

  /// Returns the converted node width when present.
  var nodeWidth: CGFloat? {
    cgFloat(node.width)
  }

  /// Returns the non-anchor children for this node.
  var children: [WidgetNodeState] {
    store.children(of: node.id)
  }

  /// Returns the popup anchor children for this node.
  var anchorChildren: [WidgetNodeState] {
    store.anchorChildren(of: node.id)
  }

  /// Returns the popup content children for this node.
  var popupChildren: [WidgetNodeState] {
    store.popupChildren(of: node.id)
  }

  /// Returns whether this node has popup anchor children.
  var hasAnchorChildren: Bool {
    !anchorChildren.isEmpty
  }

  /// Returns whether this node has popup content children.
  var hasPopupChildren: Bool {
    !popupChildren.isEmpty
  }

  /// Returns the shared popup hover region.
  var popupHoverBackground: some View {
    PopupHoverRegion { hovering in handlePopupHover(hovering) }
  }

  /// Returns the shared node style modifier.
  var nodeStyle: WidgetNodeStyle {
    WidgetNodeStyle(node: node)
  }
}

// MARK: - Image And Text

private extension WidgetNodeView {
  /// Returns whether this node has a non-empty image path.
  var hasImage: Bool {
    guard let imagePath = node.imagePath else { return false }
    return !imagePath.isEmpty
  }

  /// Returns whether this node has a non-empty icon.
  var hasIcon: Bool {
    !node.icon.isEmpty
  }

  /// Returns whether this node has a non-empty label.
  var hasLabel: Bool {
    !node.text.isEmpty
  }

  /// Returns the resolved icon color.
  var iconResolvedColor: Color {
    color(node.iconColor ?? node.color)
  }

  /// Returns the resolved label color.
  var labelResolvedColor: Color {
    color(node.labelColor ?? node.color)
  }

  /// Returns the resolved icon font.
  var iconResolvedFont: Font? {
    font(size: node.iconFontSize ?? node.fontSize)
  }

  /// Returns the resolved label font.
  var labelResolvedFont: Font? {
    font(size: node.labelFontSize ?? node.fontSize)
  }

  @ViewBuilder
  /// Returns the optional image view.
  var imageView: some View {
    renderedImageView()
  }

  @ViewBuilder
  /// Returns the optional icon text.
  var iconText: some View {
    if hasIcon {
      Text(node.icon)
        .font(iconResolvedFont)
        .foregroundStyle(iconResolvedColor)
    }
  }

  @ViewBuilder
  /// Returns the optional label text.
  var labelText: some View {
    if hasLabel {
      Text(node.text)
        .font(labelResolvedFont)
        .foregroundStyle(labelResolvedColor)
    }
  }

  /// Returns a templated image when tinting is enabled.
  func tintedImage(from image: NSImage, customImage: NSImage?) -> NSImage? {
    guard customImage != nil,
      let tint = node.iconColor ?? node.color,
      !tint.isEmpty
    else {
      return nil
    }

    let templated = image.copy() as? NSImage ?? image
    templated.isTemplate = true
    return templated
  }

  /// Returns the rendered image size.
  var imageSize: CGFloat {
    CGFloat(node.imageSize ?? 14)
  }

  /// Returns the rendered image corner radius.
  var imageCornerRadius: CGFloat {
    CGFloat(node.imageCornerRadius ?? 4)
  }

  /// Resolves the image file or falls back to the file icon.
  func resolvedImage(imagePath: String, customImage: NSImage?) -> NSImage {
    customImage ?? NSWorkspace.shared.icon(forFile: imagePath)
  }

  /// Returns the rendered image or nothing when no image path exists.
  @ViewBuilder
  func renderedImageView() -> some View {
    if hasImage, let imagePath = node.imagePath {
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

  /// Builds the shared base image view.
  func imageBaseView(
    image: NSImage,
    renderingMode: Image.TemplateRenderingMode
  ) -> some View {
    Image(nsImage: image)
      .renderingMode(renderingMode)
      .resizable()
      .interpolation(.high)
      .scaledToFit()
  }
}

// MARK: - Interaction

private extension WidgetNodeView {
  /// Applies style and mouse handling to one node surface.
  func styledMouseContent<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .onHover { hovering in
          guard node.isMouseHoverInteractive else { return }
          emitNodeHoverEvent(hovering)
        }
        .simultaneousGesture(
          TapGesture().onEnded {
            guard node.isMouseClickInteractive else { return }
            emitNodeClickEvent()
          }
        )
        .overlay(scrollOverlay)
    )
  }

  /// Applies popup anchor styling and mouse handling to one anchor surface.
  func popupAnchorSurface<Content: View>(_ content: Content) -> some View {
    let base = AnyView(content.foregroundStyle(nodeColor))
    let surfaced = popupAnchorInteractiveSurface(base)

    return AnyView(
      surfaced
        .onHover { hovering in handleAnchorHover(hovering) }
        .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
          popupContent
        }
    )
  }

  /// Applies popup behavior to a normal styled item surface.
  func popupItemSurface<Content: View>(_ content: Content) -> some View {
    styledMouseContent(content)
      .onHover { hovering in handleAnchorHover(hovering) }
      .popover(isPresented: $popupPresented, arrowEdge: .bottom) {
        popupContent
      }
  }

  /// Returns a geometry-sized event surface for the current node.
  func nodeEventSurface(tracksHover: Bool = true) -> some View {
    GeometryReader { proxy in
      // Match the final rendered node bounds instead of the icon glyph bounds.
      WidgetMouseView(
        widgetID: node.root,
        targetWidgetID: node.id,
        tracksHover: tracksHover
      )
      .frame(width: proxy.size.width, height: proxy.size.height)
      .contentShape(Rectangle())
    }
  }

  /// Returns the scroll-only overlay when the node subscribed to mouse.scrolled.
  @ViewBuilder
  var scrollOverlay: some View {
    if node.isMouseScrollInteractive {
      nodeEventSurface(tracksHover: false)
    }
  }

  /// Applies click handling for popup anchors while leaving hover to SwiftUI.
  func popupAnchorInteractiveSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .simultaneousGesture(
          TapGesture().onEnded {
            guard node.isMouseClickInteractive else { return }
            emitNodeClickEvent()
          }
        )
        .overlay(scrollOverlay)
    )
  }

  /// Emits one node-scoped hover event.
  func emitNodeHoverEvent(_ hovering: Bool) {
    let event: WidgetEvent = hovering ? .mouseEntered : .mouseExited
    EventBus.shared.emitWidgetEvent(event, widgetID: node.root, targetWidgetID: node.id)
  }

  /// Emits one node-scoped click event.
  func emitNodeClickEvent() {
    EventBus.shared.emitWidgetEvent(
      .mouseClicked,
      widgetID: node.root,
      targetWidgetID: node.id,
      button: .left
    )
  }
}
