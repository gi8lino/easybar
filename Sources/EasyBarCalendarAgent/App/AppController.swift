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
  @discardableResult
  func start() -> Bool {
    let sharedConfig: SharedRuntimeConfig

    do {
      sharedConfig = try SharedRuntimeConfig.load()
    } catch {
      logger.error(
        "failed to load shared runtime config",
        .field("error", error.localizedDescription)
      )
      return false
    }

    configureLogging(sharedConfig: sharedConfig)

    guard acquireInstanceLock(sharedConfig: sharedConfig) else {
      return false
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
      runtime = nil
      return false
    }

    return true
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
      acquireMessage: "easybar-calendar-agent acquired instance lock",
      alreadyRunningMessage: "easybar-calendar-agent already running",
      failureMessage: "easybar-calendar-agent failed to acquire single-instance lock",
    )
  }
}
