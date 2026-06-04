import Foundation

/// Native time widget.
@MainActor
final class TimeNativeWidget: NativeWidget {

  let rootID = "builtin_time"
  private let config: Config.TimeBuiltinConfig
  private lazy var controller = FormattedClockNativeWidgetController(rootID: rootID) { [config] in
    .init(
      placement: config.placement,
      style: config.style,
      format: config.format
    )
  }

  /// Creates the native time widget from an immutable config section.
  init(config: Config.TimeBuiltinConfig) {
    self.config = config
  }

  var appEventSubscriptions: Set<String> { controller.appEventSubscriptions }

  /// Starts the time widget.
  func start() {
    controller.start()
  }

  /// Stops the time widget.
  func stop() {
    controller.stop()
  }
}
