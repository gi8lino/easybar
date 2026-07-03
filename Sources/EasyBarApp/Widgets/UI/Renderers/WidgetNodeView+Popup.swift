import SwiftUI

// MARK: - Popup State

extension WidgetNodeView {
  var nodeColor: Color {
    return color(node.color)
  }

  /// Resolves an optional hex color or falls back to the default text color.
  func color(_ hex: String?) -> Color {
    guard let hex, !hex.isEmpty else {
      return Theme.defaultTextColor(snapshot: configStore.snapshot)
    }

    return Color(hex: hex, snapshot: configStore.snapshot)
  }

  /// Returns a system font for an optional point size.
  func fontValue(size: Double?) -> Font? {
    guard let size else { return nil }
    return .system(size: CGFloat(size))
  }

  /// Converts an optional `Double` into an optional `CGFloat`.
  func cgFloat(_ value: Double?) -> CGFloat? {
    guard let value else { return nil }
    return CGFloat(value)
  }

  /// Schedules a delayed popup close check.
  func schedulePopupCloseCheck() {
    Task { @MainActor in
      do {
        try await Task.sleep(nanoseconds: 80_000_000)
      } catch {
        return
      }
      closePopupIfIdle()
    }
  }

  /// Updates popup presentation from anchor hover state.
  func handleAnchorHover(_ hovering: Bool) {
    anchorHovered = hovering

    if hovering {
      guard nodeCanPresentPopup else { return }
      popupPresented = true
      return
    }

    schedulePopupCloseCheck()
  }

  /// Updates popup presentation from popup hover state.
  func handlePopupHover(_ hovering: Bool) {
    popupHovered = hovering

    guard !hovering else { return }
    schedulePopupCloseCheck()
  }

  /// Closes the popup when neither anchor nor content is hovered.
  func closePopupIfIdle() {
    guard !node.presentsPopupAutomatically else { return }
    guard !anchorHovered else { return }
    guard !popupHovered else { return }
    popupPresented = false
  }

  /// Synchronizes the AppKit popup panel with SwiftUI state.
  func updatePopupPanel(isPresented: Bool) {
    guard nodeCanPresentPopup else {
      popupPanel.close()
      return
    }

    popupPanel.update(isPresented: isPresented, content: popupPanelContent)
  }
}

// MARK: - Layout Data

extension WidgetNodeView {
  var childRow: some View {
    HStack(spacing: stackSpacing) {
      ForEach(children) { child in
        WidgetNodeView(node: child, logger: logger)
      }
    }
  }

  var stackSpacing: CGFloat {
    return CGFloat(node.spacing ?? 6)
  }

  var itemSpacing: CGFloat {
    return CGFloat(node.spacing ?? 4)
  }

  var currentValue: Double {
    return node.value ?? 0
  }

  var minValue: Double {
    return node.min ?? 0
  }

  var maxValue: Double {
    return node.max ?? 100
  }

  var stepValue: Double {
    return node.step ?? 1
  }

  var progressWidth: CGFloat {
    return CGFloat(node.width ?? 64)
  }

  var progressHeight: CGFloat {
    return CGFloat(node.height ?? 8)
  }

  var sparklineWidth: CGFloat {
    return CGFloat(node.width ?? 64)
  }

  var sparklineHeight: CGFloat {
    return CGFloat(node.height ?? 18)
  }

  var sparklineLineWidth: CGFloat {
    return CGFloat(node.lineWidth ?? 1.5)
  }

  var nodeWidth: CGFloat? {
    return cgFloat(node.width)
  }

  var children: [WidgetNodeState] {
    return store.children(of: node.id)
  }

  var anchorChildren: [WidgetNodeState] {
    return store.anchorChildren(of: node.id)
  }

  var popupChildren: [WidgetNodeState] {
    return store.popupChildren(of: node.id)
  }

  var hasAnchorChildren: Bool {
    return !anchorChildren.isEmpty
  }

  var hasPopupChildren: Bool {
    return !popupChildren.isEmpty
  }

  var popupContentResolver: WidgetPopupContentResolver {
    return WidgetPopupContentResolver(
      node: node,
      hasPopupChildren: hasPopupChildren,
      configStore: configStore,
      widgetStore: store
    )
  }

  var nodeCanPresentPopup: Bool {
    return popupContentResolver.canPresentPopup
  }

  var popupHoverBackground: some View {
    PopupHoverRegion { hovering in handlePopupHover(hovering) }
  }

  var popupPanelContent: AnyView {
    return popupContentResolver.makeContent(
      regularContent: popupContent,
      hoverBackground: popupHoverBackground
    )
  }

  var nodeStyle: WidgetNodeStyle {
    return WidgetNodeStyle(node: node)
  }
}
