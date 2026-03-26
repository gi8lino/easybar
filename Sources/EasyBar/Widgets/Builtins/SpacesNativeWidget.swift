import Foundation

/// Native wrapper node for the SwiftUI spaces widget.
final class SpacesNativeWidget: NativeWidget {

  let rootID = "builtin_spaces"

  private let aeroSpaceObserver = AeroSpaceUpdateObserver()

  /// Starts the widget and listens for AeroSpace state updates.
  func start() {
    AeroSpaceService.shared.registerConsumer(rootID)

    aeroSpaceObserver.start { [weak self] in
      self?.publish()
    }

    publish()
  }

  /// Stops the widget and unregisters AeroSpace interest.
  func stop() {
    aeroSpaceObserver.stop()
    AeroSpaceService.shared.unregisterConsumer(rootID)
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Publishes the spaces container node.
  private func publish() {
    let config = Config.shared.builtinSpaces
    let placement = config.placement
    let style = config.style

    let node = WidgetNodeState(
      id: rootID,
      root: rootID,
      kind: .spaces,
      parent: placement.groupID,
      position: placement.position,
      order: placement.order,
      icon: "",
      text: "",
      color: style.textColorHex,
      iconColor: nil,
      labelColor: nil,
      visible: true,
      role: nil,
      receivesMouseHover: nil,
      receivesMouseClick: nil,
      receivesMouseScroll: nil,
      imagePath: nil,
      imageSize: nil,
      imageCornerRadius: nil,
      fontSize: nil,
      iconFontSize: nil,
      labelFontSize: nil,
      value: nil,
      min: nil,
      max: nil,
      step: nil,
      values: nil,
      lineWidth: nil,
      paddingX: style.paddingX,
      paddingY: style.paddingY,
      paddingLeft: nil,
      paddingRight: nil,
      paddingTop: nil,
      paddingBottom: nil,
      marginX: style.marginX,
      marginY: style.marginY,
      spacing: style.spacing,
      backgroundColor: style.backgroundColorHex,
      borderColor: style.borderColorHex,
      borderWidth: style.borderWidth,
      cornerRadius: style.cornerRadius,
      opacity: style.opacity,
      width: nil,
      height: nil,
      yOffset: nil
    )

    WidgetStore.shared.apply(root: rootID, nodes: [node])
  }
}
