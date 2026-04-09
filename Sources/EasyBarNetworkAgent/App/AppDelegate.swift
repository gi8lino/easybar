import AppKit
import EasyBarNetworkAgentCore
import EasyBarShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NetworkAuthorizationPromptPresenter {
  private let logger = ProcessLogger(label: "easybar-network-agent")
  private var controller: NetworkAgentController?
  private let instanceGuard = SingleInstanceGuard()
  private var presentedAuthorizationPrompt = false

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    let runtimeConfig = SharedRuntimeConfig.current

    logger.configureRuntimeLogging(
      minimumLevel: runtimeConfig.loggingLevel,
      fileLoggingEnabled: runtimeConfig.loggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: runtimeConfig.loggingDirectory)
        .appendingPathComponent("network-agent.out")
        .path
    )

    let lockPath = defaultSingleInstanceLockPath(
      processName: "easybar-network-agent",
      directory: runtimeConfig.lockDirectory
    )

    switch instanceGuard.acquireLock(at: lockPath) {
    case .acquired:
      break

    case .alreadyRunning:
      logger.warn("easybar-network-agent already running lock_path=\(lockPath)")
      NSApp.terminate(nil)
      return

    case .failed(let reason):
      logger.error(
        "easybar-network-agent failed to acquire instance lock lock_path=\(lockPath) reason=\(reason)"
      )
      NSApp.terminate(nil)
      return
    }

    let controllerConfig = NetworkAgentControllerConfig.easyBar(
      runtimeConfig: runtimeConfig,
      appVersion: BuildInfo.appVersion
    )
    controller = NetworkAgentController(
      config: controllerConfig,
      logger: logger,
      promptPresenter: self
    )

    NSApp.setActivationPolicy(.accessory)
    guard controller?.start() == true else {
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller?.stop()
  }

  /// Prepares the app so the system location prompt can surface.
  func preparePrompt() {
    guard !presentedAuthorizationPrompt else { return }
    presentedAuthorizationPrompt = true

    let changed = NSApp.setActivationPolicy(.regular)
    logger.info("network agent promoted for authorization prompt changed=\(changed)")
    NSApp.activate(ignoringOtherApps: true)
  }

  /// Restores accessory mode after authorization resolves.
  func restoreUI() {
    guard presentedAuthorizationPrompt else { return }
    presentedAuthorizationPrompt = false

    let changed = NSApp.setActivationPolicy(.accessory)
    logger.info("network agent restored accessory mode changed=\(changed)")
  }
}
