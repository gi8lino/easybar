import Foundation

/// Native spaces widget backed by `AeroSpaceService` state.
@MainActor
final class SpacesNativeWidget: NativeWidget {

  let rootID = "builtin_spaces"
  let widgetStore: WidgetStore

  private let config: Config.SpacesBuiltinConfig
  private let aeroSpaceService: AeroSpaceService
  private let aeroSpaceObserver = AeroSpaceUpdateObserver()
  private lazy var renderer = SpacesRenderer(rootID: rootID)

  /// Creates the native spaces widget from an immutable config section.
  init(
    config: Config.SpacesBuiltinConfig,
    widgetStore: WidgetStore,
    aeroSpaceService: AeroSpaceService
  ) {
    self.config = config
    self.widgetStore = widgetStore
    self.aeroSpaceService = aeroSpaceService
  }

  /// Starts the spaces widget and registers AeroSpace interest.
  func start() {
    aeroSpaceService.registerConsumer(rootID)

    aeroSpaceObserver.start { [weak self] in
      self?.publish()
    }

    publish()
  }

  /// Stops the spaces widget and removes observers.
  func stop() {
    aeroSpaceObserver.stop()
    aeroSpaceService.unregisterConsumer(rootID)
    clearNodes()
  }

  /// Publishes the current spaces widget nodes.
  private func publish() {
    applyNodes(renderer.makeNodes(snapshot: config))
  }
}
