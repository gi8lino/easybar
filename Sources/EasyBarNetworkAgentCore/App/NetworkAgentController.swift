import EasyBarShared
import Foundation

@MainActor
public final class NetworkAgentController {
  private let runtimeConfig: SharedRuntimeConfig
  private let snapshotProvider: NetworkSnapshotProvider
  private let socketServer: NetworkSocketServer

  /// Builds the network agent controller from one runtime config.
  public init(config: SharedRuntimeConfig = .current) {
    runtimeConfig = config
    snapshotProvider = NetworkSnapshotProvider(
      refreshIntervalSeconds: config.networkAgentRefreshIntervalSeconds
    )
    socketServer = NetworkSocketServer(
      socketPath: config.networkAgentSocketPath,
      allowUnauthorizedNonSensitiveFields: config.networkAgentAllowUnauthorizedNonSensitiveFields
    )
  }

  /// Returns whether the network agent should run.
  public var isEnabled: Bool {
    runtimeConfig.networkAgentEnabled
  }

  /// Starts logging, snapshot delivery, and the network socket server.
  @discardableResult
  public func start() -> Bool {
    AgentLogger.configure(using: runtimeConfig)
    guard isEnabled else {
      AgentLogger.info("network agent disabled in config")
      return false
    }

    logStartup()

    snapshotProvider.start { [weak self] in
      self?.socketServer.broadcastSnapshots()
    }

    socketServer.start(provider: snapshotProvider)
    return true
  }

  /// Stops the network socket server and snapshot provider.
  public func stop() {
    socketServer.stop()
    snapshotProvider.stop()
  }

  /// Logs one startup snapshot for the network agent.
  private func logStartup() {
    logProcessStartup(
      snapshot: makeProcessStartupSnapshot(
        processName: "network agent",
        configPath: runtimeConfig.configPath,
        socketSummary:
          "socket path=\(runtimeConfig.networkAgentSocketPath) refresh_interval_seconds=\(runtimeConfig.networkAgentRefreshIntervalSeconds) allow_unauthorized_non_sensitive_fields=\(runtimeConfig.networkAgentAllowUnauthorizedNonSensitiveFields)",
        loggingSummary:
          "logging enabled=\(AgentLogger.fileLoggingEnabled) debug=\(AgentLogger.debugEnabled) path=\(AgentLogger.fileLoggingPath)"
      ),
      write: AgentLogger.info
    )
    AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
  }
}
