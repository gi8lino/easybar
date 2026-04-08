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

  /// Starts only the native event sources required by all active subscriptions.
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

    if mergedSubscriptions.contains("system_woke") {
      SystemEvents.shared.subscribeSystemWake()
    }

    if mergedSubscriptions.contains("sleep") {
      SystemEvents.shared.subscribeSleep()
    }

    if mergedSubscriptions.contains("space_change") {
      SystemEvents.shared.subscribeSpaceChange()
    }

    if mergedSubscriptions.contains("app_switch") {
      SystemEvents.shared.subscribeAppSwitch()
    }

    if mergedSubscriptions.contains("display_change") {
      SystemEvents.shared.subscribeDisplayChange()
    }

    if mergedSubscriptions.contains("power_source_change")
      || mergedSubscriptions.contains("charging_state_change")
    {
      PowerEvents.shared.subscribePowerSource()
    }

    if mergedSubscriptions.contains("wifi_change") {
      NetworkEvents.shared.subscribeWifi()
    }

    if mergedSubscriptions.contains("network_change") {
      NetworkEvents.shared.subscribeNetwork()
    }

    if mergedSubscriptions.contains("volume_change") || mergedSubscriptions.contains("mute_change")
    {
      VolumeEvents.shared.subscribeVolume()
    }

    if mergedSubscriptions.contains("minute_tick") {
      TimerEvents.shared.startMinuteTimer()
    }

    if mergedSubscriptions.contains("second_tick") {
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
