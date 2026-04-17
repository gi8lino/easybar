import Foundation

/// Main-actor owner of native event source subscriptions.
@MainActor
final class EventManager {
  static let shared = EventManager()

  private static let intervalTickPrefix = "interval_tick:"

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

  /// Stops only Lua-owned event subscriptions while preserving native ones.
  func stopLuaSubscriptions() {
    guard !luaSubscriptions.isEmpty else { return }
    luaSubscriptions.removeAll()
    refresh()
  }

  /// Stops all active native event sources and clears every subscription source.
  func stopAll() {
    easybarLog.debug("event manager stopAll begin")

    luaSubscriptions.removeAll()
    nativeSubscriptions.removeAll()
    stopActiveSources()
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

    stopActiveSources()
    activeSubscriptions = mergedSubscriptions
    subscribeActiveSources(mergedSubscriptions)

    easybarLog.debug("event manager refresh end active=\(activeSubscriptions)")
  }

  /// Starts every event source required by the merged subscription set.
  private func subscribeActiveSources(_ mergedSubscriptions: Set<String>) {
    let interval = Self.intervalTickInterval(in: mergedSubscriptions)

    if mergedSubscriptions.contains(AppEvent.systemWoke.rawValue) {
      SystemEvents.shared.subscribeSystemWake()
    }

    if mergedSubscriptions.contains(AppEvent.sleep.rawValue) {
      SystemEvents.shared.subscribeSleep()
    }

    if mergedSubscriptions.contains(AppEvent.spaceChange.rawValue) {
      SystemEvents.shared.subscribeSpaceChange()
    }

    if mergedSubscriptions.contains(AppEvent.appSwitch.rawValue) {
      SystemEvents.shared.subscribeAppSwitch()
    }

    if mergedSubscriptions.contains(AppEvent.displayChange.rawValue) {
      SystemEvents.shared.subscribeDisplayChange()
    }

    if mergedSubscriptions.contains(AppEvent.powerSourceChange.rawValue)
      || mergedSubscriptions.contains(AppEvent.chargingStateChange.rawValue)
    {
      PowerEvents.shared.subscribePowerSource()
    }

    if mergedSubscriptions.contains(AppEvent.volumeChange.rawValue)
      || mergedSubscriptions.contains(AppEvent.muteChange.rawValue)
    {
      VolumeEvents.shared.subscribeVolume()
    }

    if mergedSubscriptions.contains(AppEvent.minuteTick.rawValue) {
      TimerEvents.shared.startMinuteTimer()
    }

    if mergedSubscriptions.contains(AppEvent.secondTick.rawValue) {
      TimerEvents.shared.startSecondTimer()
    }

    if let interval {
      TimerEvents.shared.startIntervalTimer(interval: interval)
    }
  }

  /// Stops every currently active native event source.
  private func stopActiveSources() {
    TimerEvents.shared.stopAll()
    SystemEvents.shared.stopAll()
    PowerEvents.shared.stopAll()
    VolumeEvents.shared.stopAll()
  }

  /// Returns the shared Lua interval cadence requested by the runtime.
  private static func intervalTickInterval(in subscriptions: Set<String>) -> TimeInterval? {
    for name in subscriptions {
      guard name.hasPrefix(intervalTickPrefix) else { continue }
      let rawValue = String(name.dropFirst(intervalTickPrefix.count))
      guard let interval = TimeInterval(rawValue), interval > 0 else { continue }
      return interval
    }

    return nil
  }
}
