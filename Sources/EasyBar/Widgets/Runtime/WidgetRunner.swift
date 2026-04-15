import Foundation

final class WidgetRunner {
  static let initialEvents: [(name: String, event: AppEvent)] = [
    ("system_woke", .systemWoke),
    ("power_source_change", .powerSourceChange),
    ("charging_state_change", .chargingStateChange),
    ("wifi_change", .wifiChange),
    ("network_change", .networkChange),
    ("volume_change", .volumeChange),
    ("mute_change", .muteChange),
    ("calendar_change", .calendarChange),
    ("minute_tick", .minuteTick),
    ("second_tick", .secondTick),
    ("focus_change", .focusChange),
    ("workspace_change", .workspaceChange),
    ("space_mode_change", .spaceModeChange),
  ]

  static let shared = WidgetRunner()

  let decoder = JSONDecoder()

  var runtimeState = WidgetRuntimeState()
  var started = false
  var stdoutObserver: NSObjectProtocol?

  private init() {}

  /// Starts the widget runtime and begins observing Lua stdout.
  func start() {
    guard !started else {
      easybarLog.debug("widget runner already started")
      return
    }

    easybarLog.debug("widget runner start begin")

    started = true
    resetRuntimeState()
    startObservingRuntimeOutput()
    LuaRuntime.shared.start()

    easybarLog.debug("widget runner start end")
  }

  /// Reloads the Lua runtime and clears rendered widget state.
  func reload() {
    easybarLog.debug("widget runner reload begin")

    shutdown()
    WidgetStore.shared.clear()
    start()

    easybarLog.debug("widget runner reload end")
  }

  /// Stops the widget runtime and related event sources.
  func shutdown() {
    guard started else {
      easybarLog.debug("widget runner shutdown skipped, not started")
      return
    }

    easybarLog.debug("widget runner shutdown begin")

    stopObservingRuntimeOutput()

    started = false
    resetRuntimeState()

    EventManager.shared.stopAll()
    LuaRuntime.shared.shutdown()

    easybarLog.debug("widget runner shutdown end")
  }

  /// Resets Lua runtime handshake and subscription state.
  func resetRuntimeState() {
    runtimeState.reset()
  }
}
