import Foundation

final class EventManager {

  static let shared = EventManager()

  private var luaSubscriptions = Set<String>()
  private var nativeSubscriptions = Set<String>()
  private var activeSubscriptions = Set<String>()

  /// Replaces the current Lua runtime event subscriptions.
  func setLuaSubscriptions(_ subscriptions: Set<String>) {
    luaSubscriptions = subscriptions
    refresh()
  }

  /// Replaces the current native widget event subscriptions.
  func setNativeSubscriptions(_ subscriptions: Set<String>) {
    nativeSubscriptions = subscriptions
    refresh()
  }

  /// Replaces the current Lua runtime event subscriptions.
  func start(subscriptions: Set<String>) {
    setLuaSubscriptions(subscriptions)
  }

  /// Stops all active native event sources and clears every subscription source.
  func stopAll() {
    easybarLog.debug("event manager stopAll begin")

    luaSubscriptions.removeAll()
    nativeSubscriptions.removeAll()

    let stopStart = Date()
    stopActiveSources()
    logSlowPhase(name: "stopActiveSources", startedAt: stopStart)

    activeSubscriptions.removeAll()

    easybarLog.debug("event manager stopAll end")
  }

  /// Rebuilds active event listeners from the merged Lua and native subscriptions.
  private func refresh() {
    let mergedSubscriptions = luaSubscriptions.union(nativeSubscriptions)

    if mergedSubscriptions == activeSubscriptions {
      easybarLog.debug("event manager refresh skipped, subscriptions unchanged")
      return
    }

    let added = mergedSubscriptions.subtracting(activeSubscriptions)
    let removed = activeSubscriptions.subtracting(mergedSubscriptions)

    easybarLog.debug(
      """
      event manager refresh begin \
      merged=\(mergedSubscriptions) \
      active=\(activeSubscriptions) \
      added=\(added) \
      removed=\(removed) \
      lua=\(luaSubscriptions) \
      native=\(nativeSubscriptions)
      """
    )

    let stopStart = Date()
    stopActiveSources()
    logSlowPhase(name: "stopActiveSources", startedAt: stopStart)

    activeSubscriptions = mergedSubscriptions

    let subscribeStart = Date()
    subscribeActiveSources(mergedSubscriptions)
    logSlowPhase(name: "subscribeActiveSources", startedAt: subscribeStart)

    easybarLog.debug("event manager refresh end active=\(activeSubscriptions)")
  }

  /// Starts every event source required by the merged subscription set.
  private func subscribeActiveSources(_ mergedSubscriptions: Set<String>) {
    if mergedSubscriptions.contains(AppEvent.systemWoke.rawValue) {
      let startedAt = Date()
      SystemEvents.shared.subscribeSystemWake()
      logSlowPhase(name: "SystemEvents.subscribeSystemWake", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.sleep.rawValue) {
      let startedAt = Date()
      SystemEvents.shared.subscribeSleep()
      logSlowPhase(name: "SystemEvents.subscribeSleep", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.spaceChange.rawValue) {
      let startedAt = Date()
      SystemEvents.shared.subscribeSpaceChange()
      logSlowPhase(name: "SystemEvents.subscribeSpaceChange", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.appSwitch.rawValue) {
      let startedAt = Date()
      SystemEvents.shared.subscribeAppSwitch()
      logSlowPhase(name: "SystemEvents.subscribeAppSwitch", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.displayChange.rawValue) {
      let startedAt = Date()
      SystemEvents.shared.subscribeDisplayChange()
      logSlowPhase(name: "SystemEvents.subscribeDisplayChange", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.powerSourceChange.rawValue)
      || mergedSubscriptions.contains(AppEvent.chargingStateChange.rawValue)
    {
      let startedAt = Date()
      PowerEvents.shared.subscribePowerSource()
      logSlowPhase(name: "PowerEvents.subscribePowerSource", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.volumeChange.rawValue)
      || mergedSubscriptions.contains(AppEvent.muteChange.rawValue)
    {
      let startedAt = Date()
      VolumeEvents.shared.subscribeVolume()
      logSlowPhase(name: "VolumeEvents.subscribeVolume", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.minuteTick.rawValue) {
      let startedAt = Date()
      TimerEvents.shared.startMinuteTimer()
      logSlowPhase(name: "TimerEvents.startMinuteTimer", startedAt: startedAt)
    }

    if mergedSubscriptions.contains(AppEvent.secondTick.rawValue) {
      let startedAt = Date()
      TimerEvents.shared.startSecondTimer()
      logSlowPhase(name: "TimerEvents.startSecondTimer", startedAt: startedAt)
    }
  }

  /// Stops every currently active native event source.
  private func stopActiveSources() {
    TimerEvents.shared.stopAll()
    SystemEvents.shared.stopAll()
    PowerEvents.shared.stopAll()
    VolumeEvents.shared.stopAll()
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
    easybarLog.warn("slow event manager phase phase=\(name) duration_ms=\(milliseconds)")
  }
}
