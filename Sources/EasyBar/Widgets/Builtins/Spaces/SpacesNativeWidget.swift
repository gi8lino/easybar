import Foundation

final class SpacesNativeWidget: NativeWidget {

  let rootID = "builtin_spaces"

  private let aeroSpaceObserver = AeroSpaceUpdateObserver()
  private lazy var renderer = SpacesRenderer(rootID: rootID)

  func start() {
    AeroSpaceService.shared.registerConsumer(rootID)

    aeroSpaceObserver.start { [weak self] in
      self?.publish()
    }

    publish()
  }

  func stop() {
    aeroSpaceObserver.stop()
    AeroSpaceService.shared.unregisterConsumer(rootID)
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  private func publish() {
    WidgetStore.shared.apply(
      root: rootID,
      nodes: renderer.makeNodes(snapshot: Config.shared.builtinSpaces)
    )
  }
}
