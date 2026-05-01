import SwiftUI

// MARK: - Popup State

extension WidgetNodeView {
  var nodeColor: Color {
    color(node.color)
  }

  /// Resolves an optional hex color or falls back to the default text color.
  func color(_ hex: String?) -> Color {
    guard let hex, !hex.isEmpty else {
      return Theme.defaultTextColor
    }

    return Color(hex: hex)
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
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
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
    CGFloat(node.spacing ?? 6)
  }

  var itemSpacing: CGFloat {
    CGFloat(node.spacing ?? 4)
  }

  var currentValue: Double {
    node.value ?? 0
  }

  var minValue: Double {
    node.min ?? 0
  }

  var maxValue: Double {
    node.max ?? 100
  }

  var stepValue: Double {
    node.step ?? 1
  }

  var progressWidth: CGFloat {
    CGFloat(node.width ?? 64)
  }

  var progressHeight: CGFloat {
    CGFloat(node.height ?? 8)
  }

  var sparklineWidth: CGFloat {
    CGFloat(node.width ?? 64)
  }

  var sparklineHeight: CGFloat {
    CGFloat(node.height ?? 18)
  }

  var sparklineLineWidth: CGFloat {
    CGFloat(node.lineWidth ?? 1.5)
  }

  var nodeWidth: CGFloat? {
    cgFloat(node.width)
  }

  var children: [WidgetNodeState] {
    store.children(of: node.id)
  }

  var anchorChildren: [WidgetNodeState] {
    store.anchorChildren(of: node.id)
  }

  var popupChildren: [WidgetNodeState] {
    store.popupChildren(of: node.id)
  }

  var hasAnchorChildren: Bool {
    !anchorChildren.isEmpty
  }

  var hasPopupChildren: Bool {
    !popupChildren.isEmpty
  }

  var calendarRootPopupMode: Config.CalendarPopupMode {
    Config.shared.builtinCalendar.popupMode
  }

  var calendarRootHasPopup: Bool {
    calendarRootPopupMode != .none
  }

  var nodeCanPresentPopup: Bool {
    if node.isCalendarRoot {
      return calendarRootHasPopup
    }

    return node.kind == .popup || hasPopupChildren
  }

  var popupHoverBackground: some View {
    PopupHoverRegion { hovering in handlePopupHover(hovering) }
  }

  var popupPanelContent: AnyView {
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

  var nodeStyle: WidgetNodeStyle {
    WidgetNodeStyle(node: node)
  }
}
