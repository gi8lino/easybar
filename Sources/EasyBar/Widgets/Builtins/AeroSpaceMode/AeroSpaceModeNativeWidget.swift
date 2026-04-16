import Foundation

/// Native AeroSpace layout-mode widget backed by `AeroSpaceService` state.
@MainActor
final class AeroSpaceModeNativeWidget: NativeWidget {

  let rootID = "builtin_aerospace_mode"

  private let aeroSpaceObserver = AeroSpaceUpdateObserver()

  /// Starts the widget and registers AeroSpace interest.
  func start() {
    AeroSpaceService.shared.registerConsumer(rootID)

    aeroSpaceObserver.start { [weak self] in
      self?.publish()
    }

    publish()
  }

  /// Stops the widget and removes observers.
  func stop() {
    aeroSpaceObserver.stop()
    AeroSpaceService.shared.unregisterConsumer(rootID)
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Publishes the currently focused AeroSpace layout mode.
  private func publish() {
    let config = Config.shared.builtinAeroSpaceMode
    let placement = config.placement
    let style = config.style
    let mode = AeroSpaceService.shared.focusedLayoutMode

    let node = BuiltinNativeNodeFactory.makeItemNode(
      rootID: rootID,
      placement: placement,
      style: style,
      text: resolvedText(for: mode, config: config)
    )

    var renderedNode = node
    renderedNode.icon = resolvedIcon(for: mode, config: config)

    WidgetStore.shared.apply(root: rootID, nodes: [renderedNode])
  }

  /// Returns the configured icon for the current layout mode.
  private func resolvedIcon(
    for mode: AeroSpaceLayoutMode,
    config: Config.AeroSpaceModeBuiltinConfig
  ) -> String {
    guard config.showIcon else { return "" }

    switch mode {
    case .hTiles:
      return config.hTilesIcon
    case .vTiles:
      return config.vTilesIcon
    case .hAccordion:
      return config.hAccordionIcon
    case .vAccordion:
      return config.vAccordionIcon
    case .floating:
      return config.floatingIcon
    case .unknown:
      return config.unknownIcon
    }
  }

  /// Returns the configured label for the current layout mode.
  private func resolvedText(
    for mode: AeroSpaceLayoutMode,
    config: Config.AeroSpaceModeBuiltinConfig
  ) -> String {
    guard config.showText else { return "" }

    switch mode {
    case .hTiles:
      return config.hTilesText
    case .vTiles:
      return config.vTilesText
    case .hAccordion:
      return config.hAccordionText
    case .vAccordion:
      return config.vAccordionText
    case .floating:
      return config.floatingText
    case .unknown:
      return config.unknownText
    }
  }
}
