import EasyBarShared
import Foundation

/// Runtime controller for the calendar agent.
///
/// This type owns the long-running calendar agent services: snapshot
/// collection, calendar mutation handling, and socket delivery.
@MainActor
final class CalendarAgentRuntime {
  private let config: CalendarAgentRuntimeConfig
  private let snapshotProvider: CalendarSnapshotProvider
  private let socketServer: CalendarSocketServer
  private let logger: ProcessLogger

  /// Builds the calendar agent runtime from one host-provided config.
  init(
    config: CalendarAgentRuntimeConfig,
    logger: ProcessLogger
  ) {
    self.config = config
    self.logger = logger
    snapshotProvider = CalendarSnapshotProvider(logger: logger.child("snapshot_provider"))
    socketServer = CalendarSocketServer(
      socketPath: config.socketPath,
      appVersion: config.appVersion,
      logger: logger.child("socket_server")
    )
  }

  /// Returns whether the calendar agent should run.
  var isEnabled: Bool {
    config.isEnabled
  }

  /// Starts snapshot delivery and the calendar socket server.
  @discardableResult
  func start() -> Bool {
    guard isEnabled else {
      logger.info(
        "calendar agent disabled in config",
        .field("component", config.componentName)
      )
      return false
    }

    logProcessStartup(
      processName: config.processName,
      configPath: config.configPath,
      socketPath: config.socketPath,
      logger: logger
    )

    snapshotProvider.start { [weak self] in
      self?.socketServer.broadcastSnapshots()
    }

    socketServer.start(provider: snapshotProvider)
    return true
  }

  /// Stops the calendar socket server and snapshot provider.
  func stop() {
    socketServer.stop()
    snapshotProvider.stop()
  }
}
