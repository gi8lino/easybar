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

  /// Starts observation for system sleep notifications.
  func subscribeSleep() {
    guard observers[.sleep] == nil else { return }

    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received workspace willSleep notification")
      EventBus.shared.emit(.sleep)
    }

    observers[.sleep] = observer
    easybarLog.debug("subscribed sleep")
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
      EventBus.shared.emit(.spaceChange)
    }

    observers[.spaceChange] = observer
    easybarLog.debug("subscribed space_change")
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
      EventBus.shared.emit(.appSwitch, appName: appName)
    }

    observers[.appSwitch] = observer
    easybarLog.debug("subscribed app_switch")
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
      EventBus.shared.emit(.displayChange)
    }

    observers[.displayChange] = observer
    easybarLog.debug("subscribed display_change")
  }

  /// Removes every registered system observer.
  func stopAll() {
    pendingWakeWorkItem?.cancel()
    pendingWakeWorkItem = nil

    let workspaceCenter = NSWorkspace.shared.notificationCenter
    let defaultCenter = NotificationCenter.default

    for observer in observers.values {
      // Observers may belong to either center, so remove them from both.
      workspaceCenter.removeObserver(observer)
      defaultCenter.removeObserver(observer)
    }

    observers.removeAll()
    easybarLog.debug("stopped all system event observers")
  }

  /// Coalesces near-simultaneous wake-related notifications into one app event.
  private func scheduleWakeEmission() {
    easybarLog.debug("received workspace didWake notification")

    pendingWakeWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      DispatchQueue.main.async {
        easybarLog.debug("emitting coalesced system_woke")
        EventBus.shared.emit(.systemWoke)
      }
    }

    pendingWakeWorkItem = workItem
    wakeQueue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
  }
}
