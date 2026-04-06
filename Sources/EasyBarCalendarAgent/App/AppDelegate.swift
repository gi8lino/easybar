import Cocoa
import EasyBarShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = ProcessLogger(label: "easybar-calendar-agent")
  private lazy var controller = AppController(logger: logger)
  private let instanceGuard = SingleInstanceGuard()

  /// Starts the calendar agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    let runtimeConfig = SharedRuntimeConfig.current

    logger.configureRuntimeLogging(
      debugEnabled: runtimeConfig.loggingDebugEnabled,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("calendar-agent.out")
        .path
    )

    let lockPath = defaultSingleInstanceLockPath(
      processName: "easybar-calendar-agent",
      directory: runtimeConfig.lockDirectory
    )

    guard instanceGuard.acquireLock(at: lockPath) else {
      logger.warn("easybar-calendar-agent already running lock_path=\(lockPath)")
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
