import Foundation

/// Native spaces widget backed by `AeroSpaceService` state.
@MainActor
final class SpacesNativeWidget: NativeWidget {

  let rootID = "builtin_spaces"

  private let config: Config.SpacesBuiltinConfig
  private let aeroSpaceObserver = AeroSpaceUpdateObserver()
  private lazy var renderer = SpacesRenderer(rootID: rootID)

  /// Creates the native spaces widget from an immutable config section.
  init(config: Config.SpacesBuiltinConfig) {
    self.config = config
  }

  /// Starts the spaces widget and registers AeroSpace interest.
  func start() {
    AeroSpaceService.shared.registerConsumer(rootID)

    aeroSpaceObserver.start { [weak self] in
      self?.publish()
    }

    publish()
  }

  /// Stops the spaces widget and removes observers.
  func stop() {
    aeroSpaceObserver.stop()
    AeroSpaceService.shared.unregisterConsumer(rootID)
    clearNodes()
  }

  /// Publishes the current spaces widget nodes.
  private func publish() {
    WidgetStore.shared.apply(
      root: rootID,
      nodes: renderer.makeNodes(snapshot: config)
    )
  }
}
