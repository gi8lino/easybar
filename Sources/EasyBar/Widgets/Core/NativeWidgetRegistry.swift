import Foundation

final class NativeWidgetRegistry {

  private struct Registration {
    let enabled: Bool
    let makeWidget: () -> NativeWidget
  }

  static let shared = NativeWidgetRegistry()

  private var widgets: [NativeWidget] = []

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
    stopAll()

    Logger.info("registering native widgets")
    logConfig()
    NativeGroupRegistry.shared.reload()
    widgets = makeEnabledWidgets()
    logRegisteredWidgets()
    startWidgets()
  }

  /// Stops and clears all widgets.
  private func stopAll() {
    for widget in widgets {
      widget.stop()
    }

    widgets.removeAll()
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

  /// Logs the current built-in widget enablement snapshot.
  private func logConfig() {
    Logger.info(
      """
      native widget config \
      spaces=\(Config.shared.builtinSpaces.enabled) \
      battery=\(Config.shared.builtinBattery.enabled) \
      front_app=\(Config.shared.builtinFrontApp.enabled) \
      volume=\(Config.shared.builtinVolume.enabled) \
      wifi=\(Config.shared.builtinWiFi.enabled) \
      date=\(Config.shared.builtinDate.enabled) \
      time=\(Config.shared.builtinTime.enabled) \
      calendar=\(Config.shared.builtinCalendar.enabled) \
      calendar_popup_mode=\(Config.shared.builtinCalendar.popupMode.rawValue) \
      cpu=\(Config.shared.builtinCPU.enabled)
      """
    )
  }

  /// Logs the final registered widget ids.
  private func logRegisteredWidgets() {
    Logger.info(
      "native widgets registered count=\(widgets.count) ids=\(widgets.map(\.rootID).joined(separator: ","))"
    )
  }

  /// Starts all currently registered widgets.
  private func startWidgets() {
    for widget in widgets {
      widget.start()
    }
  }
}
