import AppKit
import EasyBarNetworkAgentCore
import EasyBarShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = ProcessLogger(label: "easybar-network-agent")
  private var controller: NetworkAgentController?
  private let instanceGuard = SingleInstanceGuard()

  /// Starts the network agent after launch.
  func applicationDidFinishLaunching(_ notification: Notification) {
    let runtimeConfig = SharedRuntimeConfig.current

    logger.configureRuntimeLogging(
      debugEnabled: runtimeConfig.loggingDebugEnabled,
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

    case .failed(let message):
      logger.error(
        "easybar-network-agent failed to acquire single-instance lock lock_path=\(lockPath) error=\(message)"
      )
      NSApp.terminate(nil)
      return
    }

    let controllerConfig = NetworkAgentControllerConfig.easyBar(
      runtimeConfig: runtimeConfig,
      appVersion: BuildInfo.appVersion
    )
    controller = NetworkAgentController(config: controllerConfig, logger: logger)

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
}
