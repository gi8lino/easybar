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

    configureLogging(runtimeConfig: sharedConfig)

    guard acquireInstanceLock(runtimeConfig: sharedConfig) else {
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
  private func configureLogging(runtimeConfig: SharedRuntimeConfig) {
    logger.configureRuntimeLogging(
      minimumLevel: runtimeConfig.loggingLevel,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("network-agent.out")
        .path
    )
  }

  /// Acquires the single-instance lock for the network agent process.
  private func acquireInstanceLock(runtimeConfig: SharedRuntimeConfig) -> Bool {
    switch instanceGuard.acquireLock(
      processName: "easybar-network-agent",
      directory: runtimeConfig.lockDirectory
    ) {
    case .acquired:
      return true

    case .alreadyRunning(let lockPath):
      logger.warn(
        "easybar-network-agent already running",
        .field("lock_path", lockPath)
      )
      return false

    case .failed(let lockPath, let reason):
      logger.error(
        "easybar-network-agent failed to acquire instance lock",
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
