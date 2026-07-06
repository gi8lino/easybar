import AppKit
import EasyBarShared
import Foundation

/// Installs macOS app lifecycle observers used to keep AeroSpace-backed UI responsive.
final class AeroSpaceAppObserver: @unchecked Sendable {
  private struct State {
    var running = false
    var appSwitchObserver: NSObjectProtocol?
    var appLaunchObserver: NSObjectProtocol?
    var appTerminationObserver: NSObjectProtocol?
  }

  private let logger: ProcessLogger
  private let notificationCenter: NotificationCenter
  private let appActivated: (NSRunningApplication) -> Void
  private let appLaunched: (NSRunningApplication) -> Void
  private let appTerminated: (NSRunningApplication) -> Void
  private let state = LockedState(State())

  /// Creates one app observer with callbacks for the observed lifecycle events.
  init(
    logger: ProcessLogger,
    notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
    appActivated: @escaping (NSRunningApplication) -> Void,
    appLaunched: @escaping (NSRunningApplication) -> Void,
    appTerminated: @escaping (NSRunningApplication) -> Void
  ) {
    self.logger = logger
    self.notificationCenter = notificationCenter
    self.appActivated = appActivated
    self.appLaunched = appLaunched
    self.appTerminated = appTerminated
  }

  /// Starts observing app activation, launch, and termination notifications.
  func start() {
    let shouldStart = state.withLock { state -> Bool in
      guard !state.running else { return false }
      state.running = true
      return true
    }

    guard shouldStart else { return }

    let appSwitchObserver = notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else {
        return
      }

      self.appActivated(app)
    }

    let appLaunchObserver = notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else {
        return
      }

      self.appLaunched(app)
    }

    let appTerminationObserver = notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard
        let self,
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication
      else {
        return
      }

      self.appTerminated(app)
    }

    let staleObservers = state.withLock { state -> [NSObjectProtocol] in
      guard state.running else {
        return [appSwitchObserver, appLaunchObserver, appTerminationObserver]
      }

      let staleObservers = [
        state.appSwitchObserver,
        state.appLaunchObserver,
        state.appTerminationObserver,
      ].compactMap { $0 }

      state.appSwitchObserver = appSwitchObserver
      state.appLaunchObserver = appLaunchObserver
      state.appTerminationObserver = appTerminationObserver

      return staleObservers
    }

    for observer in staleObservers {
      notificationCenter.removeObserver(observer)
    }

    logger.debug("aerospace app observers installed")
  }

  /// Stops observing app lifecycle notifications.
  func stop() {
    let observers = state.withLock { state -> [NSObjectProtocol] in
      let observers = [
        state.appSwitchObserver,
        state.appLaunchObserver,
        state.appTerminationObserver,
      ].compactMap { $0 }

      state.running = false
      state.appSwitchObserver = nil
      state.appLaunchObserver = nil
      state.appTerminationObserver = nil

      return observers
    }

    guard !observers.isEmpty else { return }

    for observer in observers {
      notificationCenter.removeObserver(observer)
    }

    logger.debug("aerospace app observers removed")
  }
}
