import Foundation

final class DateNativeWidget: NativeWidget {

  let rootID = "builtin_date"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.minuteTick.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()
  private lazy var renderer = DateRenderer(
    rootID: rootID,
    config: Config.shared.builtinDate
  )

  func start() {
    eventObserver.start { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == .minuteTick || event == .systemWoke else { return }
      self.publish()
    }

    publish()
  }

  func stop() {
    eventObserver.stop()
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  private func publish() {
    WidgetStore.shared.apply(
      root: rootID,
      nodes: renderer.makeNodes(snapshot: Date())
    )
  }
}
