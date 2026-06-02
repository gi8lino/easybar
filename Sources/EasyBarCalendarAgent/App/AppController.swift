import AppKit
import EasyBarCalendarCore
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

    configureLogging(sharedConfig: sharedConfig)

    guard acquireInstanceLock(sharedConfig: sharedConfig) else {
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
  private func configureLogging(sharedConfig: SharedRuntimeConfig) {
    AppShellSupport.configureLogging(
      logger: logger,
      minimumLevel: sharedConfig.loggingLevel,
      fileLoggingEnabled: sharedConfig.loggingEnabled,
      loggingDirectory: sharedConfig.loggingDirectory,
      logFileName: "calendar-agent.out"
    )
  }

  /// Acquires the single-instance lock for the calendar agent process.
  private func acquireInstanceLock(sharedConfig: SharedRuntimeConfig) -> Bool {
    AppShellSupport.acquireInstanceLock(
      instanceGuard: instanceGuard,
      processName: "easybar-calendar-agent",
      directory: sharedConfig.lockDirectory,
      logger: logger,
      alreadyRunningMessage: "easybar-calendar-agent already running",
      failureMessage: "easybar-calendar-agent failed to acquire single-instance lock"
    )
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    AppShellSupport.terminateApplication()
  }
}
