import Foundation

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

  func start() {
    controller.start()
  }

  func stop() {
    controller.stop()
  }
}
