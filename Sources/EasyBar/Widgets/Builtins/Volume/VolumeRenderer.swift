import Foundation

/// Renders the native volume widget tree from a volume snapshot.
struct VolumeRenderer: NativeWidgetRenderer {

  typealias Snapshot = VolumeSliderNativeWidget.Snapshot

  let rootID: String

  /// Builds the volume nodes for the current snapshot.
  func makeNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    guard !snapshot.config.expandToSliderOnHover else {
      return makeExpandableNodes(snapshot: snapshot)
    }

    return [
      BuiltinNativeNodeFactory.makeSliderNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style,
        text: snapshot.text,
        value: snapshot.value,
        min: snapshot.config.minValue,
        max: snapshot.config.maxValue,
        step: snapshot.step
      )
    ]
  }
}

// MARK: - Expandable Layout

extension VolumeRenderer {

  /// Builds the expandable hover layout.
  private func makeExpandableNodes(snapshot: Snapshot) -> [WidgetNodeState] {
    var nodes: [WidgetNodeState] = [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: snapshot.placement,
        style: snapshot.style
      )
    ]

    if !snapshot.style.icon.isEmpty {
      nodes.append(
        BuiltinNativeNodeFactory.makeChildItemNode(
          rootID: rootID,
          parentID: rootID,
          childID: "\(rootID)_icon",
          position: snapshot.placement.position,
          order: 0,
          icon: snapshot.style.icon,
          color: snapshot.style.textColorHex
        )
      )
    }

    nodes.append(
      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_label",
        position: snapshot.placement.position,
        order: 1,
        text: snapshot.text,
        color: snapshot.style.textColorHex,
        visible: snapshot.isHovered && !snapshot.text.isEmpty
      )
    )

    nodes.append(
      BuiltinNativeNodeFactory.makeChildSliderNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_slider",
        position: snapshot.placement.position,
        order: 2,
        value: snapshot.value,
        min: snapshot.config.minValue,
        max: snapshot.config.maxValue,
        step: snapshot.step,
        color: snapshot.style.textColorHex,
        visible: snapshot.isHovered
      )
    )

    return nodes
  }
}
