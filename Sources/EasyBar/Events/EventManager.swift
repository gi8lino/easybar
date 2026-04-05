import Foundation

final class EventManager {

  static let shared = EventManager()

  private var activeSubscriptions = Set<String>()

  /// Starts only the native event sources required by the current widget subscriptions.
  func start(subscriptions: Set<String>) {
    stopAll()

    activeSubscriptions = subscriptions

    easybarLog.debug("required events: \(subscriptions)")

    if subscriptions.contains("system_woke") {
      SystemEvents.shared.subscribeSystemWake()
    }

    if subscriptions.contains("sleep") {
      SystemEvents.shared.subscribeSleep()
    }

    if subscriptions.contains("space_change") {
      SystemEvents.shared.subscribeSpaceChange()
    }

    if subscriptions.contains("app_switch") {
      SystemEvents.shared.subscribeAppSwitch()
    }

    if subscriptions.contains("display_change") {
      SystemEvents.shared.subscribeDisplayChange()
    }

    if subscriptions.contains("power_source_change")
      || subscriptions.contains("charging_state_change")
    {
      PowerEvents.shared.subscribePowerSource()
    }

    if subscriptions.contains("wifi_change") {
      NetworkEvents.shared.subscribeWifi()
    }

    if subscriptions.contains("network_change") {
      NetworkEvents.shared.subscribeNetwork()
    }

    if subscriptions.contains("volume_change") || subscriptions.contains("mute_change") {
      VolumeEvents.shared.subscribeVolume()
    }

    if subscriptions.contains("minute_tick") {
      TimerEvents.shared.startMinuteTimer()
    }

    if subscriptions.contains("second_tick") {
      TimerEvents.shared.startSecondTimer()
    }
  }

  /// Stops all active native event sources.
  func stopAll() {
    TimerEvents.shared.stopAll()
    SystemEvents.shared.stopAll()
    NetworkEvents.shared.stopAll()
    PowerEvents.shared.stopAll()
    VolumeEvents.shared.stopAll()
    activeSubscriptions.removeAll()
  }
}
