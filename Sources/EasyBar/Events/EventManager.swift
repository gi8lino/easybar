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
    luaSubscriptions.removeAll()
    nativeSubscriptions.removeAll()
    stopActiveSources()
    activeSubscriptions.removeAll()
  }

  /// Rebuilds active event listeners from the merged Lua and native subscriptions.
  private func refresh() {
    let mergedSubscriptions = luaSubscriptions.union(nativeSubscriptions)

    stopActiveSources()
    activeSubscriptions = mergedSubscriptions

    easybarLog.debug(
      """
      required events merged=\(mergedSubscriptions) \
      lua=\(luaSubscriptions) \
      native=\(nativeSubscriptions)
      """
    )

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

    if mergedSubscriptions.contains(AppEvent.wifiChange.rawValue) {
      NetworkEvents.shared.subscribeWifi()
    }

    if mergedSubscriptions.contains(AppEvent.networkChange.rawValue) {
      NetworkEvents.shared.subscribeNetwork()
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
  }

  /// Stops every currently active native event source.
  private func stopActiveSources() {
    TimerEvents.shared.stopAll()
    SystemEvents.shared.stopAll()
    NetworkEvents.shared.stopAll()
    PowerEvents.shared.stopAll()
    VolumeEvents.shared.stopAll()
  }
}
