import Foundation

/// Native front-app widget backed by `AeroSpaceService` state.
@MainActor
final class FrontAppNativeWidget: NativeWidget {

  let rootID = "builtin_front_app"
  let widgetStore: WidgetStore

  private let config: Config.FrontAppBuiltinConfig
  private let aeroSpaceService: AeroSpaceService

  /// Creates the native front-app widget from an immutable config section.
  init(
    config: Config.FrontAppBuiltinConfig,
    widgetStore: WidgetStore,
    aeroSpaceService: AeroSpaceService
  ) {
    self.config = config
    self.widgetStore = widgetStore
    self.aeroSpaceService = aeroSpaceService
  }

  /// Starts the widget and registers AeroSpace interest.
  func start() {
    aeroSpaceService.registerConsumer(rootID) { [weak self] in
      self?.publish()
    }

    publish()
  }

  /// Stops the widget and removes observers.
  func stop() {
    aeroSpaceService.unregisterConsumer(rootID)
    clearNodes()
  }

  /// Publishes the currently focused app.
  private func publish() {
    let placement = config.placement
    let style = config.style
    let focused = currentFocusedApp()

    applyNodes(
      makeNodes(
        config: config,
        placement: placement,
        style: style,
        focused: focused
      )
    )
  }

  /// Returns the focused app already resolved by `AeroSpaceService`.
  private func currentFocusedApp() -> (name: String, bundlePath: String?) {
    guard let app = aeroSpaceService.focusedApp else {
      return ("", nil)
    }

    return (app.name, app.bundlePath)
  }

  /// Builds the widget node tree.
  private func makeNodes(
    config: Config.FrontAppBuiltinConfig,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    focused: (name: String, bundlePath: String?)
  ) -> [WidgetNodeState] {
    var nodes = [
      BuiltinNativeNodeFactory.makeRowContainerNode(
        rootID: rootID,
        placement: placement,
        style: style
      )
    ]

    appendIconNode(
      to: &nodes,
      config: config,
      placement: placement,
      style: style,
      focused: focused
    )

    appendLabelNode(
      to: &nodes,
      config: config,
      placement: placement,
      style: style,
      focused: focused
    )

    return nodes
  }

  /// Appends the icon node when enabled.
  private func appendIconNode(
    to nodes: inout [WidgetNodeState],
    config: Config.FrontAppBuiltinConfig,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    focused: (name: String, bundlePath: String?)
  ) {
    guard config.showIcon else { return }

    nodes.append(
      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_icon",
        position: placement.position,
        order: 0,
        icon: focused.bundlePath == nil ? style.icon : "",
        text: "",
        color: style.textColorHex,
        imagePath: focused.bundlePath,
        imageSize: config.iconSize,
        imageCornerRadius: config.iconCornerRadius
      )
    )
  }

  /// Appends the label node when enabled.
  private func appendLabelNode(
    to nodes: inout [WidgetNodeState],
    config: Config.FrontAppBuiltinConfig,
    placement: Config.BuiltinWidgetPlacement,
    style: Config.BuiltinWidgetStyle,
    focused: (name: String, bundlePath: String?)
  ) {
    guard config.showName else { return }

    nodes.append(
      BuiltinNativeNodeFactory.makeChildItemNode(
        rootID: rootID,
        parentID: rootID,
        childID: "\(rootID)_label",
        position: placement.position,
        order: 1,
        text: focused.name.isEmpty ? config.fallbackText : focused.name,
        color: style.textColorHex
      )
    )
  }
}
