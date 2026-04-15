import AppKit

final class SystemEvents {

  static let shared = SystemEvents()

  private var observers: [NSObjectProtocol] = []

  private init() {}

  /// Starts observation for system wake notifications.
  func subscribeSystemWake() {
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received workspace didWake notification")
      EventBus.shared.emit(.systemWoke)
    }

    observers.append(observer)
    easybarLog.debug("subscribed system_woke")
  }

  /// Starts observation for system sleep notifications.
  func subscribeSleep() {
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received workspace willSleep notification")
      EventBus.shared.emit(.sleep)
    }

    observers.append(observer)
    easybarLog.debug("subscribed sleep")
  }

  /// Starts observation for active space changes.
  func subscribeSpaceChange() {
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received workspace activeSpaceDidChange notification")
      EventBus.shared.emit(.spaceChange)
    }

    observers.append(observer)
    easybarLog.debug("subscribed space_change")
  }

  /// Starts observation for frontmost app changes.
  func subscribeAppSwitch() {
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

    observers.append(observer)
    easybarLog.debug("subscribed app_switch")
  }

  /// Starts observation for display configuration changes.
  func subscribeDisplayChange() {
    let observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { _ in
      easybarLog.debug("received didChangeScreenParameters notification")
      EventBus.shared.emit(.displayChange)
    }

    observers.append(observer)
    easybarLog.debug("subscribed display_change")
  }

  /// Removes every registered system observer.
  func stopAll() {
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    let defaultCenter = NotificationCenter.default

    for observer in observers {
      // Observers may belong to either center, so remove them from both.
      workspaceCenter.removeObserver(observer)
      defaultCenter.removeObserver(observer)
    }

    observers.removeAll()
    easybarLog.debug("stopped all system event observers")
  }
}
