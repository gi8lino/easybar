import AppKit
import EasyBarNetworkAgentCore
import EasyBarShared

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = ProcessLogger(label: "easybar-network-agent")
  private lazy var controller = NetworkAgentController(logger: logger)
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

    guard instanceGuard.acquireLock(at: lockPath) else {
      logger.warn("easybar-network-agent already running lock_path=\(lockPath)")
      NSApp.terminate(nil)
      return
    }

    NSApp.setActivationPolicy(.accessory)
    guard controller.start() else {
      NSApp.terminate(nil)
      return
    }
  }

  /// Stops the network agent before termination.
  func applicationWillTerminate(_ notification: Notification) {
    controller.stop()
  }
}
