import AppKit
import SwiftUI

struct WidgetNodeView: View {
  let node: WidgetNodeState

  @ObservedObject private var store = WidgetStore.shared

  @StateObject private var popupPanel = WidgetPopupPanelController()
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
    .onChange(of: popupPresented, initial: true) { _, presented in
      updatePopupPanel(isPresented: presented)
    }
    .onDisappear {
      popupPanel.close()
    }
  }
}

// MARK: - Top-Level Rendering

extension WidgetNodeView {
  /// Returns the rendered view for the current node kind.
  @ViewBuilder
  fileprivate var renderedNodeView: some View {
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
  fileprivate var customRenderedNodeView: some View {
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
  fileprivate var dedicatedContainerNodeView: some View {
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
  fileprivate var interactiveNodeView: some View {
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

  fileprivate var rowOrGroupView: some View {
    Group {
      if node.isCalendarRoot {
        if calendarRootHasPopup {
          nativeCalendarAnchorView {
            childRow
          }
        } else {
          styledNodeSurface(childRow)
        }
      } else if hasPopupChildren {
        popupAnchorSurface(childRow)
      } else {
        styledNodeSurface(childRow)
      }
    }
  }

  fileprivate var itemView: some View {
    if hasPopupChildren {
      return AnyView(popupItemSurface(itemContent))
    }

    return AnyView(styledNodeSurface(itemContent))
  }

  fileprivate func nativeCalendarAnchorView<Content: View>(
    @ViewBuilder content: () -> Content
  ) -> some View {
    content()
      .foregroundStyle(nodeColor)
      .modifier(nodeStyle)
      .onHover { hovering in handleAnchorHover(hovering) }
      .background {
        WidgetPopupAnchorView { anchor in
          popupPanel.updateAnchorView(anchor)
        }
      }
  }

  fileprivate var popupAnchor: some View {
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

  fileprivate var popupContent: some View {
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

extension WidgetNodeView {
  fileprivate var itemContent: some View {
    HStack(spacing: itemSpacing) {
      imageView
      iconText
      labelText
    }
  }

  fileprivate var sliderView: some View {
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

  fileprivate var progressSliderView: some View {
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

  fileprivate var progressView: some View {
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

  fileprivate var sparklineView: some View {
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

extension WidgetNodeView {
  fileprivate var nodeColor: Color {
    color(node.color)
  }

  fileprivate func color(_ hex: String?) -> Color {
    guard let hex, !hex.isEmpty else {
      return Theme.defaultTextColor
    }

    return Color(hex: hex)
  }

  fileprivate func font(size: Double?) -> Font? {
    guard let size else { return nil }
    return .system(size: CGFloat(size))
  }

  fileprivate func cgFloat(_ value: Double?) -> CGFloat? {
    guard let value else { return nil }
    return CGFloat(value)
  }

  fileprivate func schedulePopupCloseCheck() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      closePopupIfIdle()
    }
  }

  fileprivate func handleAnchorHover(_ hovering: Bool) {
    anchorHovered = hovering

    if hovering {
      guard nodeCanPresentPopup else { return }
      popupPresented = true
      return
    }

    schedulePopupCloseCheck()
  }

  fileprivate func handlePopupHover(_ hovering: Bool) {
    popupHovered = hovering

    guard !hovering else { return }
    schedulePopupCloseCheck()
  }

  fileprivate func closePopupIfIdle() {
    guard !anchorHovered else { return }
    guard !popupHovered else { return }
    popupPresented = false
  }

  fileprivate func updatePopupPanel(isPresented: Bool) {
    guard nodeCanPresentPopup else {
      popupPanel.close()
      return
    }

    popupPanel.update(isPresented: isPresented, content: popupPanelContent)
  }
}

// MARK: - Layout Data

extension WidgetNodeView {
  fileprivate var childRow: some View {
    HStack(spacing: stackSpacing) {
      ForEach(children) { child in
        WidgetNodeView(node: child)
      }
    }
  }

  fileprivate var stackSpacing: CGFloat {
    CGFloat(node.spacing ?? 6)
  }

  fileprivate var itemSpacing: CGFloat {
    CGFloat(node.spacing ?? 4)
  }

  fileprivate var currentValue: Double {
    node.value ?? 0
  }

  fileprivate var minValue: Double {
    node.min ?? 0
  }

  fileprivate var maxValue: Double {
    node.max ?? 100
  }

  fileprivate var stepValue: Double {
    node.step ?? 1
  }

  fileprivate var progressWidth: CGFloat {
    CGFloat(node.width ?? 64)
  }

  fileprivate var progressHeight: CGFloat {
    CGFloat(node.height ?? 8)
  }

  fileprivate var sparklineWidth: CGFloat {
    CGFloat(node.width ?? 64)
  }

  fileprivate var sparklineHeight: CGFloat {
    CGFloat(node.height ?? 18)
  }

  fileprivate var sparklineLineWidth: CGFloat {
    CGFloat(node.lineWidth ?? 1.5)
  }

  fileprivate var nodeWidth: CGFloat? {
    cgFloat(node.width)
  }

  fileprivate var children: [WidgetNodeState] {
    store.children(of: node.id)
  }

  fileprivate var anchorChildren: [WidgetNodeState] {
    store.anchorChildren(of: node.id)
  }

  fileprivate var popupChildren: [WidgetNodeState] {
    store.popupChildren(of: node.id)
  }

  fileprivate var hasAnchorChildren: Bool {
    !anchorChildren.isEmpty
  }

  fileprivate var hasPopupChildren: Bool {
    !popupChildren.isEmpty
  }

  fileprivate var calendarRootPopupMode: Config.CalendarPopupMode {
    Config.shared.builtinCalendar.popupMode
  }

  fileprivate var calendarRootHasPopup: Bool {
    calendarRootPopupMode != .none
  }

  fileprivate var nodeCanPresentPopup: Bool {
    if node.isCalendarRoot {
      return calendarRootHasPopup
    }

    return node.kind == .popup || hasPopupChildren
  }

  fileprivate var popupHoverBackground: some View {
    PopupHoverRegion { hovering in handlePopupHover(hovering) }
  }

  fileprivate var popupPanelContent: AnyView {
    if node.isCalendarRoot {
      switch calendarRootPopupMode {
      case .none:
        return AnyView(EmptyView())
      case .upcoming:
        return AnyView(
          NativeUpcomingCalendarPopupView()
            .background(popupHoverBackground)
        )
      case .month:
        return AnyView(
          NativeMonthCalendarPopupView()
            .background(popupHoverBackground)
        )
      }
    }

    return AnyView(
      popupContent
        .background(popupHoverBackground)
    )
  }

  fileprivate var nodeStyle: WidgetNodeStyle {
    WidgetNodeStyle(node: node)
  }
}

// MARK: - Image And Text

extension WidgetNodeView {
  fileprivate var hasImage: Bool {
    guard let imagePath = node.imagePath else { return false }
    return !imagePath.isEmpty
  }

  fileprivate var hasIcon: Bool {
    !node.icon.isEmpty
  }

  fileprivate var hasLabel: Bool {
    !node.text.isEmpty
  }

  fileprivate var iconResolvedColor: Color {
    color(node.iconColor ?? node.color)
  }

  fileprivate var labelResolvedColor: Color {
    color(node.labelColor ?? node.color)
  }

  fileprivate var iconResolvedFont: Font? {
    font(size: node.iconFontSize ?? node.fontSize)
  }

  fileprivate var labelResolvedFont: Font? {
    font(size: node.labelFontSize ?? node.fontSize)
  }

  @ViewBuilder
  fileprivate var imageView: some View {
    renderedImageView()
  }

  @ViewBuilder
  fileprivate var iconText: some View {
    if hasIcon {
      Text(node.icon)
        .font(iconResolvedFont)
        .foregroundStyle(iconResolvedColor)
    }
  }

  @ViewBuilder
  fileprivate var labelText: some View {
    if hasLabel {
      Text(node.text)
        .font(labelResolvedFont)
        .foregroundStyle(labelResolvedColor)
    }
  }

  fileprivate func tintedImage(from image: NSImage, customImage: NSImage?) -> NSImage? {
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

  fileprivate var imageSize: CGFloat {
    CGFloat(node.imageSize ?? 14)
  }

  fileprivate var imageCornerRadius: CGFloat {
    CGFloat(node.imageCornerRadius ?? 4)
  }

  fileprivate func resolvedImage(imagePath: String, customImage: NSImage?) -> NSImage {
    customImage ?? NSWorkspace.shared.icon(forFile: imagePath)
  }

  @ViewBuilder
  fileprivate func renderedImageView() -> some View {
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

  fileprivate func imageBaseView(
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

extension WidgetNodeView {
  fileprivate func styledNodeSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .overlay(nodeMouseOverlay)
    )
  }

  fileprivate func styledMouseContent<Content: View>(_ content: Content) -> some View {
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

  fileprivate func popupAnchorSurface<Content: View>(_ content: Content) -> some View {
    let base = AnyView(content.foregroundStyle(nodeColor))
    let surfaced = popupAnchorInteractiveSurface(base)

    return AnyView(
      surfaced
        .onHover { hovering in handleAnchorHover(hovering) }
        .background {
          WidgetPopupAnchorView { anchor in
            popupPanel.updateAnchorView(anchor)
          }
        }
    )
  }

  fileprivate func popupItemSurface<Content: View>(_ content: Content) -> some View {
    content
      .modifier(nodeStyle)
      .contentShape(Rectangle())
      .overlay(popupAnchorMouseOverlay)
      .onHover { hovering in handleAnchorHover(hovering) }
      .background {
        WidgetPopupAnchorView { anchor in
          popupPanel.updateAnchorView(anchor)
        }
      }
  }

  fileprivate func nodeEventSurface(tracksHover: Bool = true) -> some View {
    GeometryReader { proxy in
      WidgetMouseView(
        widgetID: node.root,
        targetWidgetID: node.id,
        tracksHover: tracksHover
      )
      .frame(width: proxy.size.width, height: proxy.size.height)
      .contentShape(Rectangle())
    }
  }

  @ViewBuilder
  fileprivate var scrollOverlay: some View {
    if node.isMouseScrollInteractive {
      nodeEventSurface(tracksHover: false)
    }
  }

  @ViewBuilder
  fileprivate var nodeMouseOverlay: some View {
    if node.isMouseHoverInteractive || node.isMouseClickInteractive || node.isMouseScrollInteractive
    {
      nodeEventSurface(tracksHover: node.isMouseHoverInteractive)
    }
  }

  fileprivate func popupAnchorInteractiveSurface<Content: View>(_ content: Content) -> some View {
    AnyView(
      content
        .modifier(nodeStyle)
        .contentShape(Rectangle())
        .overlay(popupAnchorMouseOverlay)
    )
  }

  @ViewBuilder
  fileprivate var popupAnchorMouseOverlay: some View {
    if node.isMouseClickInteractive || node.isMouseScrollInteractive || hasPopupChildren
      || node.kind == .popup
    {
      nodeEventSurface(tracksHover: true)
    }
  }

  fileprivate func emitNodeHoverEvent(_ hovering: Bool) {
    let event: WidgetEvent = hovering ? .mouseEntered : .mouseExited
    EventBus.shared.emitWidgetEvent(event, widgetID: node.root, targetWidgetID: node.id)
  }

  fileprivate func emitNodeClickEvent() {
    EventBus.shared.emitWidgetEvent(
      .mouseClicked,
      widgetID: node.root,
      targetWidgetID: node.id,
      button: .left
    )
  }
}
