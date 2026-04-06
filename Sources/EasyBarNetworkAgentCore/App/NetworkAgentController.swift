import EasyBarShared
import Foundation

@MainActor
public final class NetworkAgentController {
  private let runtimeConfig: SharedRuntimeConfig
  private let snapshotProvider: NetworkSnapshotProvider
  private let socketServer: NetworkSocketServer
  private let logger: ProcessLogger

  /// Builds the network agent controller from one runtime config.
  public init(
    config: SharedRuntimeConfig = .current,
    logger: ProcessLogger
  ) {
    runtimeConfig = config
    self.logger = logger
    snapshotProvider = NetworkSnapshotProvider(
      refreshIntervalSeconds: config.networkAgentRefreshIntervalSeconds,
      logger: logger
    )
    socketServer = NetworkSocketServer(
      socketPath: config.networkAgentSocketPath,
      allowUnauthorizedNonSensitiveFields: config.networkAgentAllowUnauthorizedNonSensitiveFields,
      logger: logger
    )
  }

  /// Returns whether the network agent should run.
  public var isEnabled: Bool {
    runtimeConfig.networkAgentEnabled
  }

  /// Starts snapshot delivery and the network socket server.
  @discardableResult
  public func start() -> Bool {
    guard isEnabled else {
      logger.info("network agent disabled in config")
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
          "logging enabled=\(logger.fileLoggingEnabled) debug=\(logger.debugEnabled) path=\(logger.fileLoggingPath)"
      ),
      write: logger.info
    )
    logger.info("debug logging=\(logger.debugEnabled)")
  }
}
