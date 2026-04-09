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
      minimumLevel: runtimeConfig.loggingLevel,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("calendar-agent.out")
        .path
    )

    let lockPath = defaultSingleInstanceLockPath(
      processName: "easybar-calendar-agent",
      directory: runtimeConfig.lockDirectory
    )

    switch instanceGuard.acquireLock(at: lockPath) {
    case .acquired:
      break

    case .alreadyRunning:
      logger.warn("easybar-calendar-agent already running lock_path=\(lockPath)")
      NSApp.terminate(nil)
      return

    case .failed(let message):
      logger.error(
        "easybar-calendar-agent failed to acquire single-instance lock lock_path=\(lockPath) error=\(message)"
      )
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
