import Foundation

/// Renders the native Wi-Fi widget tree from a Wi-Fi snapshot.
struct WiFiRenderer: NativeWidgetRenderer {

  typealias Snapshot = WiFiNativeWidget.Snapshot

  private enum DetailLayout {
    static let rowSpacing: Double = 2
    static let columnSpacing: Double = 8
  }

  let rootID: String

  /// Builds the Wi-Fi nodes for the current snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    if snapshot.config.surface == .hover && snapshot.config.hoverSurface == .popup {
      return makePopupNodes(snapshot: snapshot)
    }

    return makeInlineNodes(snapshot: snapshot)
  }
}

// MARK: - Inline Layout

extension WiFiRenderer {
  /// Creates inline nodes.
  private func makeInlineNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    var nodes = makeAnchorNodes(snapshot: snapshot)

    guard snapshot.inlineContentVisible else {
      return nodes
    }

    appendInlineContentNodes(snapshot: snapshot, to: &nodes)
    return nodes
  }

  /// Appends inline field or details nodes only when they should take layout space.
  private func appendInlineContentNodes(snapshot: Snapshot, to nodes: inout [WidgetNodeState]) {
    switch snapshot.content {
    case .icon:
      break

    case .field(let text):
      guard !text.isEmpty else { return }

      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: rootID,
          childID: "\(rootID)_label",
          position: snapshot.config.placement.position,
          order: 1,
          text: text,
          color: snapshot.config.inlineTextColorHex,
          spacing: 4
        )
      )

    case .details(let rows):
      appendInlineDetailGrid(
        rows: rows,
        snapshot: snapshot,
        to: &nodes
      )
    }
  }

  /// Appends a two-column inline detail grid.
  private func appendInlineDetailGrid(
    rows: [WiFiPresentation.DetailRow],
    snapshot: Snapshot,
    to nodes: inout [WidgetNodeState]
  ) {
    guard !rows.isEmpty else { return }

    let gridID = "\(rootID)_details"

    nodes.append(
      BuiltinNativeNodeFactory.makeRowNode(
        rootID: rootID,
        parentID: rootID,
        rowID: gridID,
        position: snapshot.config.placement.position,
        order: 1,
        spacing: DetailLayout.columnSpacing
      )
    )

    appendDetailColumns(
      rows: rows,
      parentID: gridID,
      idPrefix: "\(rootID)_detail",
      position: snapshot.config.placement.position,
      color: snapshot.config.inlineTextColorHex,
      visible: true,
      to: &nodes
    )
  }
}

// MARK: - Popup Layout

extension WiFiRenderer {
  /// Creates popup nodes.
  private func makePopupNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    var nodes = makeAnchorNodes(snapshot: snapshot)

    switch snapshot.content {
    case .icon:
      break

    case .field(let text):
      appendPopupField(
        text: text,
        snapshot: snapshot,
        to: &nodes
      )

    case .details(let rows):
      appendPopupDetailGrid(
        rows: rows,
        snapshot: snapshot,
        to: &nodes
      )
    }

    return nodes
  }

  /// Appends popup content for a single field value.
  private func appendPopupField(
    text: String,
    snapshot: Snapshot,
    to nodes: inout [WidgetNodeState]
  ) {
    guard !text.isEmpty else { return }

    let popup = snapshot.config.popup
    var popupNode = BuiltinNativeNodeFactory.makePopupContentColumnNode(
      rootID: rootID,
      contentID: "\(rootID)_popup",
      position: snapshot.config.placement.position,
      order: 0,
      visible: snapshot.popupVisible,
      paddingX: popup.paddingX,
      paddingY: popup.paddingY,
      spacing: 4,
      backgroundColor: popup.backgroundColorHex,
      borderColor: popup.borderColorHex,
      borderWidth: popup.borderWidth,
      cornerRadius: popup.cornerRadius,
      opacity: 1
    )
    popupNode.marginX = popup.marginX
    popupNode.marginY = popup.marginY
    nodes.append(popupNode)

    nodes.append(
      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: "\(rootID)_popup",
        childID: "\(rootID)_popup_text",
        position: snapshot.config.placement.position,
        order: 0,
        text: text,
        color: popup.textColorHex ?? snapshot.config.inlineTextColorHex,
        visible: snapshot.popupVisible
      )
    )
  }

  /// Appends popup content as two real columns: labels and values.
  private func appendPopupDetailGrid(
    rows: [WiFiPresentation.DetailRow],
    snapshot: Snapshot,
    to nodes: inout [WidgetNodeState]
  ) {
    guard !rows.isEmpty else { return }

    let popup = snapshot.config.popup
    let gridID = "\(rootID)_popup_details"

    var popupNode = BuiltinNativeNodeFactory.makePopupContentRowNode(
      rootID: rootID,
      contentID: gridID,
      position: snapshot.config.placement.position,
      order: 0,
      visible: snapshot.popupVisible,
      paddingX: popup.paddingX,
      paddingY: popup.paddingY,
      spacing: DetailLayout.columnSpacing,
      backgroundColor: popup.backgroundColorHex,
      borderColor: popup.borderColorHex,
      borderWidth: popup.borderWidth,
      cornerRadius: popup.cornerRadius,
      opacity: 1
    )
    popupNode.marginX = popup.marginX
    popupNode.marginY = popup.marginY
    nodes.append(popupNode)

    appendDetailColumns(
      rows: rows,
      parentID: gridID,
      idPrefix: "\(rootID)_popup_detail",
      position: snapshot.config.placement.position,
      color: popup.textColorHex ?? snapshot.config.inlineTextColorHex,
      visible: snapshot.popupVisible,
      to: &nodes
    )
  }
}

// MARK: - Shared Nodes

extension WiFiRenderer {
  /// Creates the always-visible Wi-Fi anchor nodes.
  private func makeAnchorNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: snapshot.config.placement,
        style: snapshot.config.style
      ),

      BuiltinNativeNodeFactory.makeChildWiFiIndicatorNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: snapshot.config.placement.position,
        order: 0,
        signalLevel: snapshot.signalLevel,
        state: snapshot.visualState.rawValue,
        activeColor: snapshot.activeColorHex,
        inactiveColor: snapshot.inactiveColorHex,
        width: 20,
        height: 13
      ),
    ]
  }

  /// Appends one label column and one value column under the given parent row.
  private func appendDetailColumns(
    rows: [WiFiPresentation.DetailRow],
    parentID: String,
    idPrefix: String,
    position: WidgetPosition,
    color: String?,
    visible: Bool,
    to nodes: inout [WidgetNodeState]
  ) {
    let labelColumnID = "\(idPrefix)_labels"
    let valueColumnID = "\(idPrefix)_values"

    nodes.append(
      BuiltinNativeNodeFactory.makeColumnNode(
        rootID: rootID,
        parentID: parentID,
        columnID: labelColumnID,
        position: position,
        order: 0,
        spacing: DetailLayout.rowSpacing
      )
    )

    nodes.append(
      BuiltinNativeNodeFactory.makeColumnNode(
        rootID: rootID,
        parentID: parentID,
        columnID: valueColumnID,
        position: position,
        order: 1,
        spacing: DetailLayout.rowSpacing
      )
    )

    for (index, row) in rows.enumerated() {
      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: labelColumnID,
          childID: "\(idPrefix)_label_\(index)",
          position: position,
          order: index,
          text: "\(row.labelText):",
          color: color,
          visible: visible,
          spacing: 0
        )
      )

      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: valueColumnID,
          childID: "\(idPrefix)_value_\(index)",
          position: position,
          order: index,
          text: row.valueText,
          color: color,
          visible: visible,
          spacing: 0
        )
      )
    }
  }
}
