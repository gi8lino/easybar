import AppKit
import EasyBarNetworkAgentCore
import EasyBarShared

/// App-level controller for the network agent process.
///
/// This type owns macOS application concerns such as logging setup, the
/// single-instance guard, activation policy changes, and authorization prompt
/// presentation. The reusable agent behavior lives in `NetworkAgentRuntime`.
@MainActor
final class AppController: NetworkAuthorizationPromptPresenter {
  private let logger = ProcessLogger(label: "easybar-network-agent")
  private let instanceGuard = SingleInstanceGuard()

  private var runtime: NetworkAgentRuntime?
  private var presentedAuthorizationPrompt = false

  /// Starts the network agent app shell and runtime.
  func start() {
    let sharedConfig = SharedRuntimeConfig.current

    configureLogging(sharedConfig: sharedConfig)

    guard acquireInstanceLock(sharedConfig: sharedConfig) else {
      terminateApplication()
    }

    let runtimeConfig = NetworkAgentRuntimeConfig.easyBar(
      runtimeConfig: sharedConfig,
      appVersion: BuildInfo.appVersion
    )

    runtime = NetworkAgentRuntime(
      config: runtimeConfig,
      logger: logger.child("runtime"),
      promptPresenter: self
    )

    NSApp.setActivationPolicy(.accessory)

    guard runtime?.start() == true else {
      terminateApplication()
    }
  }

  /// Stops the network agent runtime.
  func stop() {
    runtime?.stop()
  }

  /// Prepares the app so the system location prompt can surface.
  func preparePrompt() {
    guard !presentedAuthorizationPrompt else { return }
    presentedAuthorizationPrompt = true

    let changed = NSApp.setActivationPolicy(.regular)
    logger.info(
      "network agent promoted for authorization prompt",
      .field("changed", changed)
    )
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Restores accessory mode after authorization resolves.
  func restoreUI() {
    guard presentedAuthorizationPrompt else { return }
    presentedAuthorizationPrompt = false

    let changed = NSApp.setActivationPolicy(.accessory)
    logger.info(
      "network agent restored accessory mode",
      .field("changed", changed)
    )
  }

  /// Configures process logging from the shared runtime config.
  private func configureLogging(sharedConfig: SharedRuntimeConfig) {
    AppShellSupport.configureLogging(
      logger: logger,
      minimumLevel: sharedConfig.loggingLevel,
      fileLoggingEnabled: sharedConfig.loggingEnabled,
      loggingDirectory: sharedConfig.loggingDirectory,
      logFileName: "network-agent.out"
    )
  }

  /// Acquires the single-instance lock for the network agent process.
  private func acquireInstanceLock(sharedConfig: SharedRuntimeConfig) -> Bool {
    AppShellSupport.acquireInstanceLock(
      instanceGuard: instanceGuard,
      processName: "easybar-network-agent",
      directory: sharedConfig.lockDirectory,
      logger: logger,
      alreadyRunningMessage: "easybar-network-agent already running",
      failureMessage: "easybar-network-agent failed to acquire instance lock"
    )
  }

  /// Terminates the application immediately.
  private func terminateApplication() -> Never {
    AppShellSupport.terminateApplication()
  }
}
