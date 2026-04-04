import Cocoa
import EasyBarShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = AppController()
  private let instanceGuard = SingleInstanceGuard()

  /// Starts the calendar agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    let lockPath = defaultSingleInstanceLockPath(processName: "easybar-calendar-agent")

    // private let startupLogger = ProcessLogger(label: "easybar-calendar-agent")
    guard instanceGuard.acquireLock(at: lockPath) else {
      calendarAgentLog.warn("easybar-calendar-agent already running lock_path=\(lockPath)")
      NSApp.terminate(nil)
      return
    }

    NSApp.setActivationPolicy(.accessory)
    guard controller.start() else {
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the calendar agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }
}
