import EasyBarShared
import Foundation

@MainActor
final class NativeWidgetRegistry {
  private struct Registration {
    let enabled: Bool
    let makeWidget: () -> NativeWidget
  }

  private static var sharedInstance: NativeWidgetRegistry?

  /// Returns the configured shared native widget registry.
  static var shared: NativeWidgetRegistry {
    guard let sharedInstance else {
      fatalError(
        "NativeWidgetRegistry.bootstrap(logger:) must be called before NativeWidgetRegistry.shared"
      )
    }

    return sharedInstance
  }

  /// Configures the shared native widget registry.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = NativeWidgetRegistry(logger: logger)
  }

  private let logger: ProcessLogger
  private var widgets: [NativeWidget] = []

  private init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Starts all enabled native widgets.
  func start() {
    registerAll()
  }

  /// Rebuilds the native widget list from config.
  func reload() {
    registerAll()
  }

  /// Stops all native widgets.
  func stop() {
    stopAll()
  }

  /// Registers all enabled native widgets.
  private func registerAll() {
    logger.info("native widget registry registerAll begin")

    stopAll()

    logger.info("registering native widgets")
    logConfig()

    NativeGroupRegistry.shared.reload()
    widgets = makeEnabledWidgets()

    logRegisteredWidgets()

    applyNativeEventSubscriptions()
    startWidgets()

    logger.info("native widget registry registerAll end")
  }

  /// Stops and clears all widgets.
  private func stopAll() {
    if !widgets.isEmpty {
      logger.info("native widget registry stopping", "count", widgets.count)
    }

    for widget in widgets {
      logger.debug("stopping native widget", "id", widget.rootID)
      widget.stop()
    }

    widgets.removeAll()
    EventManager.shared.setNativeSubscriptions([])
    NativeGroupRegistry.shared.clear()
  }

  /// Builds the enabled native widget list from the current config.
  private func makeEnabledWidgets() -> [NativeWidget] {
    registrations().compactMap(makeWidgetIfEnabled)
  }

  /// Returns the native widget registration list for the current config.
  private func registrations() -> [Registration] {
    [
      Registration(enabled: Config.shared.builtinSpaces.enabled) { SpacesNativeWidget() },
      Registration(enabled: Config.shared.builtinBattery.enabled) { BatteryNativeWidget() },
      Registration(enabled: Config.shared.builtinFrontApp.enabled) { FrontAppNativeWidget() },
      Registration(enabled: Config.shared.builtinAeroSpaceMode.enabled) {
        AeroSpaceModeNativeWidget()
      },
      Registration(enabled: Config.shared.builtinVolume.enabled) { VolumeSliderNativeWidget() },
      Registration(enabled: Config.shared.builtinWiFi.enabled) { WiFiNativeWidget() },
      Registration(enabled: Config.shared.builtinDate.enabled) { DateNativeWidget() },
      Registration(enabled: Config.shared.builtinTime.enabled) { TimeNativeWidget() },
      Registration(enabled: Config.shared.builtinCalendar.enabled) { CalendarNativeWidget() },
      Registration(enabled: Config.shared.builtinCPU.enabled) { CPUSparklineNativeWidget() },
    ]
  }

  /// Builds one native widget when its registration is enabled.
  private func makeWidgetIfEnabled(_ registration: Registration) -> NativeWidget? {
    guard registration.enabled else { return nil }
    return registration.makeWidget()
  }

  /// Applies the merged native widget event subscriptions to the event manager.
  private func applyNativeEventSubscriptions() {
    let subscriptions = widgets.reduce(into: Set<String>()) { result, widget in
      result.formUnion(widget.appEventSubscriptions)
    }

    logger.debug("native widget event subscriptions", "subscriptions", subscriptions)
    EventManager.shared.setNativeSubscriptions(subscriptions)
  }

  /// Logs the current built-in widget enablement snapshot.
  private func logConfig() {
    logger.info(
      "native widget config",
      "spaces", Config.shared.builtinSpaces.enabled,
      "battery", Config.shared.builtinBattery.enabled,
      "front_app", Config.shared.builtinFrontApp.enabled,
      "aerospace_mode", Config.shared.builtinAeroSpaceMode.enabled,
      "volume", Config.shared.builtinVolume.enabled,
      "wifi", Config.shared.builtinWiFi.enabled,
      "date", Config.shared.builtinDate.enabled,
      "time", Config.shared.builtinTime.enabled,
      "calendar", Config.shared.builtinCalendar.enabled,
      "calendar_popup_mode", Config.shared.builtinCalendar.popupMode.rawValue,
      "cpu", Config.shared.builtinCPU.enabled
    )
  }

  /// Logs the final registered widget ids.
  private func logRegisteredWidgets() {
    logger.info(
      "native widgets registered",
      "count", widgets.count,
      "ids", widgets.map(\.rootID).joined(separator: ",")
    )
  }

  /// Starts all currently registered widgets.
  private func startWidgets() {
    for widget in widgets {
      logger.debug("starting native widget", "id", widget.rootID)
      widget.start()
    }
  }
}
