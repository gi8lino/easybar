import AppKit
import EasyBarShared

/// App-level controller for the calendar agent process.
///
/// This type owns macOS application concerns such as logging setup, the
/// single-instance guard, activation policy, and runtime creation. The
/// long-running agent behavior lives in `CalendarAgentRuntime`.
@MainActor
final class AppController {
  private let logger = ProcessLogger(label: "easybar-calendar-agent")
  private let instanceGuard = SingleInstanceGuard()

  private var runtime: CalendarAgentRuntime?

  /// Starts the calendar agent app shell and runtime.
  func start() {
    let sharedConfig = SharedRuntimeConfig.current

    configureLogging(runtimeConfig: sharedConfig)

    guard acquireInstanceLock(runtimeConfig: sharedConfig) else {
      terminateApplication()
    }

    let runtimeConfig = CalendarAgentRuntimeConfig.easyBar(
      runtimeConfig: sharedConfig,
      appVersion: BuildInfo.appVersion
    )

    runtime = CalendarAgentRuntime(
      config: runtimeConfig,
      logger: logger.child("runtime")
    )

    NSApp.setActivationPolicy(.accessory)

    guard runtime?.start() == true else {
      terminateApplication()
    }
  }

  /// Stops the calendar agent runtime.
  func stop() {
    runtime?.stop()
  }

  /// Configures process logging from the shared runtime config.
  private func configureLogging(runtimeConfig: SharedRuntimeConfig) {
    logger.configureRuntimeLogging(
      minimumLevel: runtimeConfig.loggingLevel,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("calendar-agent.out")
        .path
    )
  }

  /// Acquires the single-instance lock for the calendar agent process.
  private func acquireInstanceLock(runtimeConfig: SharedRuntimeConfig) -> Bool {
    switch instanceGuard.acquireLock(
      processName: "easybar-calendar-agent",
      directory: runtimeConfig.lockDirectory
    ) {
    case .acquired:
      return true

    case .alreadyRunning(let lockPath):
      logger.warn(
        "easybar-calendar-agent already running",
        .field("lock_path", lockPath)
      )
      return false

    case .failed(let lockPath, let reason):
      logger.error(
        "easybar-calendar-agent failed to acquire single-instance lock",
        .field("lock_path", lockPath),
        .field("reason", reason)
      )
      return false
    }
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    NSApp.terminate(nil)
    fatalError("Application should have terminated")
  }
}
