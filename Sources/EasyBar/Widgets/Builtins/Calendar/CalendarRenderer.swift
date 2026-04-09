import Foundation

/// Renders the native calendar anchor from a calendar snapshot.
///
/// Popup presentation is handled by:
/// - `WidgetNodeView`
/// - `WidgetPopupPanelController`
/// - `NativeUpcomingCalendarPopupView`
/// - `NativeMonthCalendarPopupView`
///
/// So this renderer is responsible only for the anchor node tree.
struct CalendarRenderer: NativeWidgetRenderer {

  typealias Snapshot = CalendarNativeWidget.Snapshot

  let rootID: String

  /// Builds the calendar anchor nodes for the current snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    switch snapshot.config.anchor.layout {
    case .stack:
      return makeStack(snapshot)
    case .inline:
      return makeInline(snapshot)
    case .item:
      return makeItem(snapshot)
    }
  }
}

// MARK: - Anchor Layouts

extension CalendarRenderer {

  /// Builds the stacked two-line calendar anchor layout.
  private func makeStack(_ snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config
    let anchor = config.anchor
    let placement = config.placement
    let style = config.style

    return [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: placement,
        style: style
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: placement.position,
        order: 0,
        icon: style.icon,
        color: style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeColumnNode(
        rootID: rootID,
        parentID: rootID,
        columnID: "\(rootID)_text_column",
        position: placement.position,
        order: 1,
        spacing: anchor.lineSpacing
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_text_column",
        childID: "\(rootID)_top",
        position: placement.position,
        order: 0,
        text: format(snapshot.now, anchor.topFormat),
        color: anchor.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_text_column",
        childID: "\(rootID)_bottom",
        position: placement.position,
        order: 1,
        text: format(snapshot.now, anchor.bottomFormat),
        color: anchor.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds the inline two-part calendar anchor layout.
  private func makeInline(_ snapshot: Snapshot) -> [WidgetNodeState] {
    let config = snapshot.config
    let anchor = config.anchor
    let placement = config.placement
    let style = config.style

    return [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: placement,
        style: style
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: placement.position,
        order: 0,
        icon: style.icon,
        color: style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_left",
        position: placement.position,
        order: 1,
        text: format(snapshot.now, anchor.topFormat),
        color: anchor.topTextColorHex ?? style.textColorHex
      ),

      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_right",
        position: placement.position,
        order: 2,
        text: format(snapshot.now, anchor.bottomFormat),
        color: anchor.bottomTextColorHex ?? style.textColorHex
      ),
    ]
  }

  /// Builds the single-item calendar anchor layout.
  private func makeItem(_ snapshot: Snapshot) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeItemNode(
        rootID: rootID,
        placement: snapshot.config.placement,
        style: snapshot.config.style,
        text: format(snapshot.now, snapshot.config.anchor.itemFormat)
      )
    ]
  }
}

// MARK: - Formatting

extension CalendarRenderer {

  /// Formats one date using the configured calendar anchor format.
  private func format(_ date: Date, _ format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
  }
}
