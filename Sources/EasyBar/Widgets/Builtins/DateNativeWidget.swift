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

  /// Starts the date widget.
  func start() {
    eventObserver.start { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == .minuteTick || event == .systemWoke else { return }
      self.publish()
    }

    publish()
  }

  /// Stops the date widget.
  func stop() {
    eventObserver.stop()
    WidgetStore.shared.apply(root: rootID, nodes: [])
  }

  /// Publishes the current date.
  private func publish() {
    let config = Config.shared.builtinDate

    let node = BuiltinNativeNodeFactory.makeItemNode(
      rootID: rootID,
      placement: config.placement,
      style: config.style,
      text: makeFormatter(format: config.format).string(from: Date())
    )

    WidgetStore.shared.apply(root: rootID, nodes: [node])
  }

  /// Builds one formatter for the configured date format.
  private func makeFormatter(format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter
  }
}
