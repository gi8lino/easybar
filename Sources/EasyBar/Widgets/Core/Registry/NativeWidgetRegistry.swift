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
    easybarLog.info("native widget registry registerAll begin")

    let stopStart = Date()
    stopAll()
    logSlowPhase(name: "stopAll", startedAt: stopStart)

    easybarLog.info("registering native widgets")
    logConfig()

    let groupReloadStart = Date()
    NativeGroupRegistry.shared.reload()
    logSlowPhase(name: "NativeGroupRegistry.reload", startedAt: groupReloadStart)

    let makeWidgetsStart = Date()
    widgets = makeEnabledWidgets()
    logSlowPhase(name: "makeEnabledWidgets", startedAt: makeWidgetsStart)

    logRegisteredWidgets()

    let subscriptionsStart = Date()
    applyNativeEventSubscriptions()
    logSlowPhase(name: "applyNativeEventSubscriptions", startedAt: subscriptionsStart)

    let startWidgetsStart = Date()
    startWidgets()
    logSlowPhase(name: "startWidgets", startedAt: startWidgetsStart)

    easybarLog.info("native widget registry registerAll end")
  }

  /// Stops and clears all widgets.
  private func stopAll() {
    if !widgets.isEmpty {
      easybarLog.info("native widget registry stopping count=\(widgets.count)")
    }

    for widget in widgets {
      let startedAt = Date()
      easybarLog.debug("stopping native widget id=\(widget.rootID)")
      widget.stop()
      logSlowWidgetPhase(
        action: "stop",
        widgetID: widget.rootID,
        startedAt: startedAt
      )
    }

    widgets.removeAll()

    let subscriptionsStart = Date()
    EventManager.shared.setNativeSubscriptions([])
    logSlowPhase(name: "EventManager.setNativeSubscriptions(empty)", startedAt: subscriptionsStart)

    let clearGroupsStart = Date()
    NativeGroupRegistry.shared.clear()
    logSlowPhase(name: "NativeGroupRegistry.clear", startedAt: clearGroupsStart)
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

    easybarLog.debug("native widget event subscriptions=\(subscriptions)")
    EventManager.shared.setNativeSubscriptions(subscriptions)
  }

  /// Logs the current built-in widget enablement snapshot.
  private func logConfig() {
    easybarLog.info(
      """
      native widget config \
      spaces=\(Config.shared.builtinSpaces.enabled) \
      battery=\(Config.shared.builtinBattery.enabled) \
      front_app=\(Config.shared.builtinFrontApp.enabled) \
      aerospace_mode=\(Config.shared.builtinAeroSpaceMode.enabled) \
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
    easybarLog.info(
      "native widgets registered count=\(widgets.count) ids=\(widgets.map(\.rootID).joined(separator: ","))"
    )
  }

  /// Starts all currently registered widgets.
  private func startWidgets() {
    for widget in widgets {
      let startedAt = Date()
      easybarLog.debug("starting native widget id=\(widget.rootID)")
      widget.start()
      logSlowWidgetPhase(
        action: "start",
        widgetID: widget.rootID,
        startedAt: startedAt
      )
    }
  }

  /// Logs one overall registry phase duration when it looks unexpectedly slow.
  private func logSlowPhase(
    name: String,
    startedAt: Date,
    slowThreshold: TimeInterval = 0.1
  ) {
    let elapsed = Date().timeIntervalSince(startedAt)
    guard elapsed >= slowThreshold else { return }

    let milliseconds = Int((elapsed * 1000).rounded())
    easybarLog.warn("slow native widget registry phase phase=\(name) duration_ms=\(milliseconds)")
  }

  /// Logs one widget-specific phase duration when it looks unexpectedly slow.
  private func logSlowWidgetPhase(
    action: String,
    widgetID: String,
    startedAt: Date,
    slowThreshold: TimeInterval = 0.1
  ) {
    let elapsed = Date().timeIntervalSince(startedAt)
    guard elapsed >= slowThreshold else { return }

    let milliseconds = Int((elapsed * 1000).rounded())
    easybarLog.warn(
      "slow native widget phase action=\(action) widget_id=\(widgetID) duration_ms=\(milliseconds)"
    )
  }
}
