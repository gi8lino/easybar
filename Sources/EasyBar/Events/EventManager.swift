import Foundation

/// Main-actor owner of native event source subscriptions.
@MainActor
final class EventManager {
  static let shared = EventManager()

  private static let intervalTickPrefix = "interval_tick:"

  private enum ManagedSource: Hashable {
    case systemWake
    case sleep
    case spaceChange
    case appSwitch
    case displayChange
    case powerSource
    case volume
    case minuteTick
    case secondTick
  }

  private var luaSubscriptions = Set<String>()
  private var nativeSubscriptions = Set<String>()
  private var activeSubscriptions = Set<String>()
  private var activeSources = Set<ManagedSource>()
  private var activeInterval: TimeInterval?

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
    activeSources.removeAll()
    activeInterval = nil

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
    let desiredSources = Self.requiredSources(for: mergedSubscriptions)
    let sourcesToAdd = desiredSources.subtracting(activeSources)
    let sourcesToRemove = activeSources.subtracting(desiredSources)
    let desiredInterval = Self.intervalTickInterval(in: mergedSubscriptions)
    let intervalChanged = desiredInterval != activeInterval

    easybarLog.debug(
      """
      event manager refresh begin \
      merged=\(mergedSubscriptions) \
      active=\(activeSubscriptions) \
      added=\(added) \
      removed=\(removed) \
      source_add=\(sourcesToAdd) \
      source_remove=\(sourcesToRemove) \
      interval=\(String(describing: desiredInterval)) \
      previous_interval=\(String(describing: activeInterval)) \
      lua=\(luaSubscriptions) \
      native=\(nativeSubscriptions)
      """
    )

    unsubscribeSources(sourcesToRemove)

    if intervalChanged, activeInterval != nil {
      TimerEvents.shared.stopIntervalTimer()
    }

    activeSubscriptions = mergedSubscriptions
    subscribeSources(sourcesToAdd)

    if intervalChanged, let desiredInterval {
      TimerEvents.shared.startIntervalTimer(interval: desiredInterval)
    }

    activeSources = desiredSources
    activeInterval = desiredInterval

    easybarLog.debug("event manager refresh end active=\(activeSubscriptions)")
  }

  /// Starts the newly required event sources.
  private func subscribeSources(_ sources: Set<ManagedSource>) {
    for source in sources {
      switch source {
      case .systemWake:
        SystemEvents.shared.subscribeSystemWake()
      case .sleep:
        SystemEvents.shared.subscribeSleep()
      case .spaceChange:
        SystemEvents.shared.subscribeSpaceChange()
      case .appSwitch:
        SystemEvents.shared.subscribeAppSwitch()
      case .displayChange:
        SystemEvents.shared.subscribeDisplayChange()
      case .powerSource:
        PowerEvents.shared.subscribePowerSource()
      case .volume:
        VolumeEvents.shared.subscribeVolume()
      case .minuteTick:
        TimerEvents.shared.startMinuteTimer()
      case .secondTick:
        TimerEvents.shared.startSecondTimer()
      }
    }
  }

  /// Stops the event sources that are no longer required.
  private func unsubscribeSources(_ sources: Set<ManagedSource>) {
    for source in sources {
      switch source {
      case .systemWake:
        SystemEvents.shared.unsubscribeSystemWake()
      case .sleep:
        SystemEvents.shared.unsubscribeSleep()
      case .spaceChange:
        SystemEvents.shared.unsubscribeSpaceChange()
      case .appSwitch:
        SystemEvents.shared.unsubscribeAppSwitch()
      case .displayChange:
        SystemEvents.shared.unsubscribeDisplayChange()
      case .powerSource:
        PowerEvents.shared.unsubscribePowerSource()
      case .volume:
        VolumeEvents.shared.unsubscribeVolume()
      case .minuteTick:
        TimerEvents.shared.stopMinuteTimer()
      case .secondTick:
        TimerEvents.shared.stopSecondTimer()
      }
    }
  }

  /// Stops every currently active native event source.
  private func stopActiveSources() {
    TimerEvents.shared.stopAll()
    SystemEvents.shared.stopAll()
    PowerEvents.shared.stopAll()
    VolumeEvents.shared.stopAll()
  }

  /// Returns the concrete native sources required by the merged subscription set.
  private static func requiredSources(for subscriptions: Set<String>) -> Set<ManagedSource> {
    var sources = Set<ManagedSource>()

    if subscriptions.contains(AppEvent.systemWoke.rawValue) {
      sources.insert(.systemWake)
    }

    if subscriptions.contains(AppEvent.sleep.rawValue) {
      sources.insert(.sleep)
    }

    if subscriptions.contains(AppEvent.spaceChange.rawValue) {
      sources.insert(.spaceChange)
    }

    if subscriptions.contains(AppEvent.appSwitch.rawValue) {
      sources.insert(.appSwitch)
    }

    if subscriptions.contains(AppEvent.displayChange.rawValue) {
      sources.insert(.displayChange)
    }

    if subscriptions.contains(AppEvent.powerSourceChange.rawValue)
      || subscriptions.contains(AppEvent.chargingStateChange.rawValue)
    {
      sources.insert(.powerSource)
    }

    if subscriptions.contains(AppEvent.volumeChange.rawValue)
      || subscriptions.contains(AppEvent.muteChange.rawValue)
    {
      sources.insert(.volume)
    }

    if subscriptions.contains(AppEvent.minuteTick.rawValue) {
      sources.insert(.minuteTick)
    }

    if subscriptions.contains(AppEvent.secondTick.rawValue) {
      sources.insert(.secondTick)
    }

    return sources
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
