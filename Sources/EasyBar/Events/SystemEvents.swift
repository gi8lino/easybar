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
      EventBus.shared.emit(.systemWoke)
    }

    observers.append(observer)
    Logger.debug("subscribed system_woke")
  }

  /// Starts observation for system sleep notifications.
  func subscribeSleep() {
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.willSleepNotification,
      object: nil,
      queue: .main
    ) { _ in
      EventBus.shared.emit(.sleep)
    }

    observers.append(observer)
    Logger.debug("subscribed sleep")
  }

  /// Starts observation for active space changes.
  func subscribeSpaceChange() {
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      EventBus.shared.emit(.spaceChange)
    }

    observers.append(observer)
    Logger.debug("subscribed space_change")
  }

  /// Starts observation for frontmost app changes.
  func subscribeAppSwitch() {
    let observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { notification in
      if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
        as? NSRunningApplication
      {
        EventBus.shared.emit(.appSwitch, appName: app.localizedName ?? "")
      }
    }

    observers.append(observer)
    Logger.debug("subscribed app_switch")
  }

  /// Starts observation for display configuration changes.
  func subscribeDisplayChange() {
    let observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { _ in
      EventBus.shared.emit(.displayChange)
    }

    observers.append(observer)
    Logger.debug("subscribed display_change")
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
  }
}
