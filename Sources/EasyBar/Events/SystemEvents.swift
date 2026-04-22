import AppKit
import Foundation

final class SystemEvents {
  static let shared = SystemEvents()

  private var observers: [ObserverKind: NSObjectProtocol] = [:]
  private let wakeQueue = DispatchQueue(label: "easybar.system-events.wake")
  private var pendingWakeWorkItem: DispatchWorkItem?

  private enum ObserverKind: Hashable {
    case systemWake
    case sleep
    case spaceChange
    case appSwitch
    case displayChange
  }

  private init() {}

  /// Starts observation for system wake notifications.
  func subscribeSystemWake() {
    guard observers[.systemWake] == nil else { return }

    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.scheduleWakeEmission()
    }

    observers[.systemWake] = observer
    easybarLog.debug("subscribed system_woke")
  }

  /// Stops observation for system wake notifications.
  func unsubscribeSystemWake() {
    removeObserver(.systemWake)
  }

  /// Starts observation for system sleep notifications.
  func subscribeSleep() {
    guard observers[.sleep] == nil else { return }

    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received workspace willSleep notification")
      Task {
        await EventHub.shared.emit(.sleep)
      }
    }

    observers[.sleep] = observer
    easybarLog.debug("subscribed sleep")
  }

  /// Stops observation for system sleep notifications.
  func unsubscribeSleep() {
    removeObserver(.sleep)
  }

  /// Starts observation for active space changes.
  func subscribeSpaceChange() {
    guard observers[.spaceChange] == nil else { return }

    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received workspace activeSpaceDidChange notification")
      Task {
        await EventHub.shared.emit(.spaceChange)
      }
    }

    observers[.spaceChange] = observer
    easybarLog.debug("subscribed space_change")
  }

  /// Stops observation for active space changes.
  func unsubscribeSpaceChange() {
    removeObserver(.spaceChange)
  }

  /// Starts observation for frontmost app changes.
  func subscribeAppSwitch() {
    guard observers[.appSwitch] == nil else { return }

    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { notification in
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else {
        easybarLog.debug("received didActivateApplication notification without app payload")
        return
      }

      let appName = app.localizedName ?? ""
      easybarLog.debug("received didActivateApplication notification app=\(appName)")

      Task {
        await EventHub.shared.emit(.appSwitch, appName: appName)
      }
    }

    observers[.appSwitch] = observer
    easybarLog.debug("subscribed app_switch")
  }

  /// Stops observation for frontmost app changes.
  func unsubscribeAppSwitch() {
    removeObserver(.appSwitch)
  }

  /// Starts observation for display configuration changes.
  func subscribeDisplayChange() {
    guard observers[.displayChange] == nil else { return }

    let observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received didChangeScreenParameters notification")
      Task {
        await EventHub.shared.emit(.displayChange)
      }
    }

    observers[.displayChange] = observer
    easybarLog.debug("subscribed display_change")
  }

  /// Stops observation for display configuration changes.
  func unsubscribeDisplayChange() {
    removeObserver(.displayChange)
  }

  /// Removes every registered system observer.
  func stopAll() {
    pendingWakeWorkItem?.cancel()
    pendingWakeWorkItem = nil
    unsubscribeSystemWake()
    unsubscribeSleep()
    unsubscribeSpaceChange()
    unsubscribeAppSwitch()
    unsubscribeDisplayChange()
    easybarLog.debug("stopped all system event observers")
  }

  /// Coalesces near-simultaneous wake-related notifications into one app event.
  private func scheduleWakeEmission() {
    easybarLog.debug("received workspace didWake notification")

    pendingWakeWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      DispatchQueue.main.async {
        easybarLog.debug("emitting coalesced system_woke")
        Task {
          await EventHub.shared.emit(.systemWoke)
        }
      }
    }

    pendingWakeWorkItem = workItem
    wakeQueue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
  }

  /// Removes one registered observer when present.
  private func removeObserver(_ kind: ObserverKind) {
    guard let observer = observers.removeValue(forKey: kind) else { return }

    NSWorkspace.shared.notificationCenter.removeObserver(observer)
    NotificationCenter.default.removeObserver(observer)
  }
}
