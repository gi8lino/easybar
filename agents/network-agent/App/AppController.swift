import EasyBarShared
import Foundation

@MainActor
final class AppController {
  private let runtimeConfig: SharedRuntimeConfig
  private let snapshotProvider: NetworkSnapshotProvider
  private let socketServer: NetworkSocketServer

  init(config: SharedRuntimeConfig = .current) {
    runtimeConfig = config
    snapshotProvider = NetworkSnapshotProvider(
      refreshIntervalSeconds: config.networkAgentRefreshIntervalSeconds
    )
    socketServer = NetworkSocketServer(socketPath: config.networkAgentSocketPath)
  }

  func start() {
    AgentLogger.configure(using: runtimeConfig)
    logStartup()

    snapshotProvider.start { [weak self] in
      self?.socketServer.broadcastSnapshots()
    }

    socketServer.start(provider: snapshotProvider)
  }

  func stop() {
    socketServer.stop()
    snapshotProvider.stop()
  }

  /// Logs one startup snapshot for the network agent.
  private func logStartup() {
    let bundle = Bundle.main
    let info = bundle.infoDictionary ?? [:]

    logProcessStartup(
      snapshot: ProcessStartupSnapshot(
        processName: "network agent",
        bundlePath: bundle.bundleURL.path,
        executablePath: bundle.executableURL?.path ?? "unknown",
        version: info["CFBundleShortVersionString"] as? String ?? "unknown",
        build: info["CFBundleVersion"] as? String ?? "unknown",
        bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
        processIdentifier: ProcessInfo.processInfo.processIdentifier,
        configPath: runtimeConfig.configPath,
        socketSummary: "socket path=\(runtimeConfig.networkAgentSocketPath) refresh_interval_seconds=\(runtimeConfig.networkAgentRefreshIntervalSeconds)",
        loggingSummary: "logging enabled=\(AgentLogger.fileLoggingEnabled) debug=\(AgentLogger.debugEnabled) path=\(AgentLogger.fileLoggingPath)"
      ),
      write: AgentLogger.info
    )
    AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
  }
}
