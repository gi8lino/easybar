import AppKit
import EasyBarNetworkAgentCore
import EasyBarShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = NetworkAgentController()
  private let instanceGuard = SingleInstanceGuard()

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    let lockPath = defaultSingleInstanceLockPath(processName: "easybar-network-agent")

    guard instanceGuard.acquireLock(at: lockPath) else {
      networkAgentLog.warn("already running lock_path=\(lockPath)")
      NSApp.terminate(nil)
      return
    }

    NSApp.setActivationPolicy(.accessory)
    guard controller.start() else {
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }
}
