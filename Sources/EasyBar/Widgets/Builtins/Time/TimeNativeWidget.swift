import Foundation

/// Native time widget.
final class TimeNativeWidget: NativeWidget {

  let rootID = "builtin_time"

  var appEventSubscriptions: Set<String> {
    [
      AppEvent.secondTick.rawValue,
      AppEvent.systemWoke.rawValue,
    ]
  }

  private let eventObserver = EasyBarEventObserver()

  /// Starts the time widget.
  func start() {
    eventObserver.start { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == .secondTick || event == .systemWoke else { return }
      self.publish()
    }

    publish()
  }

  /// Stops the time widget.
  func stop() {
    eventObserver.stop()
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Publishes the current time.
  private func publish() {
    let config = Config.shared.builtinTime

    let node = BuiltinNativeNodeFactory.makeItemNode(
      rootID: rootID,
      placement: config.placement,
      style: config.style,
      text: makeFormatter(format: config.format).string(from: Date())
    )

    WidgetStore.shared.apply(root: rootID, nodes: [node])
  }

  /// Builds one formatter for the configured time format.
  private func makeFormatter(format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter
  }
}
