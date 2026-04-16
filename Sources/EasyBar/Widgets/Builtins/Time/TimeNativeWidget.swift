import Foundation

/// Native time widget.
@MainActor
final class TimeNativeWidget: NativeWidget {

  let rootID = "builtin_time"
  private lazy var controller = FormattedClockNativeWidgetController(rootID: rootID) {
    let config = Config.shared.builtinTime
    return .init(
      placement: config.placement,
      style: config.style,
      format: config.format
    )
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
