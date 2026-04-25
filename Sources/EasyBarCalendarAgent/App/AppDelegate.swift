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

    switch instanceGuard.acquireLock(
      processName: "easybar-calendar-agent",
      directory: runtimeConfig.lockDirectory
    ) {
    case .acquired:
      break

    case .alreadyRunning(let lockPath):
      logger.warn(
        """
        easybar-calendar-agent already running
        lock_path=\(lockPath)
        """)
      terminateApplication()

    case .failed(let lockPath, let reason):
      logger.error(
        """
        easybar-calendar-agent failed to acquire single-instance lock
        lock_path=\(lockPath)
        error=\(reason)
        """)
      terminateApplication()
    }

    NSApp.setActivationPolicy(.accessory)
    guard controller.start() else {
      terminateApplication()
    }
  }

  /// Stops the calendar agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
  }
}
