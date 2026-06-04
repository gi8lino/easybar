import Foundation

/// Native date widget backed by the shared formatted-clock controller.
@MainActor
final class DateNativeWidget: NativeWidget {

  let rootID = "builtin_date"
  private let config: Config.DateBuiltinConfig
  private lazy var controller = FormattedClockNativeWidgetController(rootID: rootID) { [config] in
    .init(
      placement: config.placement,
      style: config.style,
      format: config.format
    )
  }

  /// Creates the native date widget from an immutable config section.
  init(config: Config.DateBuiltinConfig) {
    self.config = config
  }

  var appEventSubscriptions: Set<String> { controller.appEventSubscriptions }

  /// Starts the date widget.
  func start() {
    controller.start()
  }

  /// Stops the date widget.
  func stop() {
    controller.stop()
  }
}
