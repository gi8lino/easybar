import Foundation

/// Native date widget backed by the shared formatted-clock controller.
@MainActor
final class DateNativeWidget: NativeWidget {

  let rootID = "builtin_date"
  private lazy var controller = FormattedClockNativeWidgetController(rootID: rootID) {
    let config = Config.shared.builtinDate
    return .init(
      placement: config.placement,
      style: config.style,
      format: config.format
    )
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
