import EasyBarShared
import Foundation

@MainActor
final class NativeWidgetRegistry {
  private struct Registration {
    let enabled: Bool
    let makeWidget: () -> NativeWidget
  }

  /// Shared native widget registry.
  static var shared = NativeWidgetRegistry(
    logger: ProcessLogger(label: "easybar.bootstrap.native_widgets"),
    config: .shared
  )

  /// Configures the shared native widget registry.
  static func bootstrap(logger: ProcessLogger, config: Config = .shared) {
    shared = NativeWidgetRegistry(logger: logger, config: config)
  }

  private let logger: ProcessLogger
  private let config: Config
  private var widgets: [NativeWidget] = []

  private init(logger: ProcessLogger, config: Config) {
    self.logger = logger
    self.config = config
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
      logger.info(
        "native widget registry stopping",
        .field("count", widgets.count),
      )
    }

    for widget in widgets {
      logger.debug(
        "stopping native widget",
        .field("id", widget.rootID),
      )
      widget.stop()
    }

    widgets.removeAll()
    EventManager.shared.setNativeSubscriptions([])
    NativeGroupRegistry.shared.clear()
  }

  /// Builds the enabled native widget list from the current config.
  private func makeEnabledWidgets() -> [NativeWidget] {
    return registrations().compactMap(makeWidgetIfEnabled)
  }

  /// Returns the native widget registration list for the current config.
  private func registrations() -> [Registration] {
    [
      Registration(enabled: config.builtinSpaces.enabled) { SpacesNativeWidget() },
      Registration(enabled: config.builtinBattery.enabled) { BatteryNativeWidget() },
      Registration(enabled: config.builtinFrontApp.enabled) { FrontAppNativeWidget() },
      Registration(enabled: config.builtinAeroSpaceMode.enabled) {
        AeroSpaceModeNativeWidget()
      },
      Registration(enabled: config.builtinVolume.enabled) { VolumeSliderNativeWidget() },
      Registration(enabled: config.builtinWiFi.enabled) { WiFiNativeWidget() },
      Registration(enabled: config.builtinDate.enabled) { DateNativeWidget() },
      Registration(enabled: config.builtinTime.enabled) { TimeNativeWidget() },
      Registration(enabled: config.builtinCalendar.enabled) { CalendarNativeWidget() },
      Registration(enabled: config.builtinCPU.enabled) { CPUSparklineNativeWidget() },
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

    logger.debug(
      "native widget event subscriptions",
      .field("subscriptions", subscriptions),
    )
    EventManager.shared.setNativeSubscriptions(subscriptions)
  }

  /// Logs the current built-in widget enablement snapshot.
  private func logConfig() {
    logger.info(
      "native widget config",
      .field("spaces", config.builtinSpaces.enabled),
      .field("battery", config.builtinBattery.enabled),
      .field("front_app", config.builtinFrontApp.enabled),
      .field("aerospace_mode", config.builtinAeroSpaceMode.enabled),
      .field("volume", config.builtinVolume.enabled),
      .field("wifi", config.builtinWiFi.enabled),
      .field("date", config.builtinDate.enabled),
      .field("time", config.builtinTime.enabled),
      .field("calendar", config.builtinCalendar.enabled),
      .field("calendar_popup_mode", config.builtinCalendar.popupMode.rawValue),
      .field("cpu", config.builtinCPU.enabled),
    )
  }

  /// Logs the final registered widget ids.
  private func logRegisteredWidgets() {
    logger.info(
      "native widgets registered",
      .field("count", widgets.count),
      .field("ids", widgets.map(\.rootID).joined(separator: ",")),
    )
  }

  /// Starts all currently registered widgets.
  private func startWidgets() {
    for widget in widgets {
      logger.debug(
        "starting native widget",
        .field("id", widget.rootID),
      )
      widget.start()
    }
  }
}
