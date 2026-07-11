import EasyBarShared
import Foundation

/// Adapts the IPC socket server's callback-style API into async runtime commands.
actor RuntimeSocketCommandAdapter {
  /// IPC server for external commands and metrics.
  private let socketServer: SocketServer
  /// Shared runtime metrics collector.
  private let metricsCoordinator: MetricsCoordinator

  /// Creates one socket command adapter.
  init(
    logger: ProcessLogger,
    metricsCoordinator: MetricsCoordinator,
    socketServer: SocketServer? = nil
  ) {
    self.metricsCoordinator = metricsCoordinator
    self.socketServer =
      socketServer
      ?? SocketServer(
        logger: logger,
        metricsCoordinator: metricsCoordinator
      )
  }

  /// Starts accepting socket commands and config validation requests.
  func start(
    commandHandler: @escaping (IPC.Command) async -> Void,
    validateConfigHandler: @escaping (String?) async -> IPC.Message
  ) async {
    await metricsCoordinator.setSnapshotHandler { [weak self] snapshot in
      Task {
        await self?.broadcastMetrics(snapshot)
      }
    }

    socketServer.start { command in
      Task {
        await commandHandler(command)
      }
    } validateConfigHandler: { configPathOverride in
      await validateConfigHandler(configPathOverride)
    }
  }

  /// Stops accepting socket commands and metrics streams.
  func stop() async {
    await metricsCoordinator.setSnapshotHandler(nil)
    socketServer.stop()
  }

  /// Rebinds the IPC socket server when the configured socket path changed.
  @discardableResult
  func reloadConfiguration(socketPath: String) -> SocketServer.ReloadOutcome {
    socketServer.reloadConfiguration(socketPath: socketPath)
  }

  /// Broadcasts one metrics snapshot through the IPC socket server.
  private func broadcastMetrics(_ snapshot: IPC.MetricsSnapshot) {
    socketServer.broadcastMetrics(snapshot)
  }
}
