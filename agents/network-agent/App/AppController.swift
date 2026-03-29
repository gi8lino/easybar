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
    logProcessStartup(
      snapshot: makeProcessStartupSnapshot(
        processName: "network agent",
        configPath: runtimeConfig.configPath,
        socketSummary: "socket path=\(runtimeConfig.networkAgentSocketPath) refresh_interval_seconds=\(runtimeConfig.networkAgentRefreshIntervalSeconds)",
        loggingSummary: "logging enabled=\(AgentLogger.fileLoggingEnabled) debug=\(AgentLogger.debugEnabled) path=\(AgentLogger.fileLoggingPath)"
      ),
      write: AgentLogger.info
    )
    AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
  }
}
