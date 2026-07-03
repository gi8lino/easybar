import EasyBarShared
import Foundation

/// Runtime controller for the reusable network agent core.
///
/// This type owns the long-running agent services: snapshot collection,
/// authorization-aware network data access, and socket delivery.
@MainActor
public final class NetworkAgentRuntime {
  private let config: NetworkAgentRuntimeConfig
  private let snapshotProvider: NetworkSnapshotProvider
  private let socketServer: NetworkSocketServer
  private let logger: ProcessLogger

  /// Builds the network agent runtime from one host-provided config.
  public init(
    config: NetworkAgentRuntimeConfig,
    logger: ProcessLogger,
    promptPresenter: NetworkAuthorizationPromptPresenter? = nil
  ) {
    self.config = config
    self.logger = logger
    snapshotProvider = NetworkSnapshotProvider(
      componentName: config.componentName,
      refreshIntervalSeconds: config.refreshIntervalSeconds,
      logger: logger.child("snapshot_provider"),
      promptPresenter: promptPresenter
    )
    socketServer = NetworkSocketServer(
      componentName: config.componentName,
      socketPath: config.socketPath,
      appVersion: config.appVersion,
      allowUnauthorizedNonSensitiveFields: config.allowUnauthorizedFieldsWithoutLocation,
      logger: logger.child("socket_server")
    )
  }

  /// Returns whether the network agent should run.
  public var isEnabled: Bool {
    return config.isEnabled
  }

  /// Starts snapshot delivery and the network socket server.
  @discardableResult
  public func start() -> Bool {
    guard isEnabled else {
      logger.info(
        "network agent disabled in config",
        .field("component", config.componentName)
      )
      return false
    }

    logProcessStartup(
      processName: config.processName,
      configPath: config.configPath,
      socketPath: "\(config.socketPath)",
      logger: logger
    )

    logger.info(
      "network agent config",
      .field("component", config.componentName),
      .field("refresh_interval_seconds", config.refreshIntervalSeconds),
      .field(
        "allow_unauthorized_fields_without_location",
        config.allowUnauthorizedFieldsWithoutLocation
      )
    )

    snapshotProvider.start { [weak self] in
      Task { @MainActor in
        self?.socketServer.broadcastSnapshots()
      }
    }

    socketServer.start(provider: snapshotProvider)
    return true
  }

  /// Stops the network socket server and snapshot provider.
  public func stop() {
    socketServer.stop()
    snapshotProvider.stop()
  }
}
