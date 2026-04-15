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

    let resetStart = Date()
    resetRuntimeState()
    logSlowPhase(name: "resetRuntimeState", startedAt: resetStart)

    let observeStart = Date()
    startObservingRuntimeOutput()
    logSlowPhase(name: "startObservingRuntimeOutput", startedAt: observeStart)

    let luaStart = Date()
    LuaRuntime.shared.start()
    logSlowPhase(name: "LuaRuntime.start", startedAt: luaStart)

    easybarLog.debug("widget runner start end")
  }

  /// Reloads the Lua runtime and clears rendered widget state.
  func reload() {
    easybarLog.debug("widget runner reload begin")

    let shutdownStart = Date()
    shutdown()
    logSlowPhase(name: "shutdown", startedAt: shutdownStart)

    let clearStart = Date()
    WidgetStore.shared.clear()
    logSlowPhase(name: "WidgetStore.clear", startedAt: clearStart)

    let startStart = Date()
    start()
    logSlowPhase(name: "start", startedAt: startStart)

    easybarLog.debug("widget runner reload end")
  }

  /// Stops the widget runtime and related event sources.
  func shutdown() {
    guard started else {
      easybarLog.debug("widget runner shutdown skipped, not started")
      return
    }

    easybarLog.debug("widget runner shutdown begin")

    let stopObserveStart = Date()
    stopObservingRuntimeOutput()
    logSlowPhase(name: "stopObservingRuntimeOutput", startedAt: stopObserveStart)

    started = false

    let resetStart = Date()
    resetRuntimeState()
    logSlowPhase(name: "resetRuntimeState", startedAt: resetStart)

    let eventsStopStart = Date()
    EventManager.shared.stopAll()
    logSlowPhase(name: "EventManager.stopAll", startedAt: eventsStopStart)

    let luaShutdownStart = Date()
    LuaRuntime.shared.shutdown()
    logSlowPhase(name: "LuaRuntime.shutdown", startedAt: luaShutdownStart)

    easybarLog.debug("widget runner shutdown end")
  }

  /// Resets Lua runtime handshake and subscription state.
  func resetRuntimeState() {
    runtimeState.reset()
  }

  /// Logs one phase duration when it looks unexpectedly slow.
  private func logSlowPhase(
    name: String,
    startedAt: Date,
    slowThreshold: TimeInterval = 0.1
  ) {
    let elapsed = Date().timeIntervalSince(startedAt)
    guard elapsed >= slowThreshold else { return }

    let milliseconds = Int((elapsed * 1000).rounded())
    easybarLog.warn("slow widget runner phase phase=\(name) duration_ms=\(milliseconds)")
  }
}
