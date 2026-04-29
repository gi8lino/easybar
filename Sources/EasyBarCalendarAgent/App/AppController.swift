import EasyBarShared
import Foundation

@MainActor
final class AppController {
  private let runtimeConfig: SharedRuntimeConfig
  private let snapshotProvider: CalendarSnapshotProvider
  private let socketServer: CalendarSocketServer
  private let logger: ProcessLogger

  /// Builds the calendar agent controller from one runtime config.
  init(
    config: SharedRuntimeConfig = .current,
    logger: ProcessLogger
  ) {
    runtimeConfig = config
    self.logger = logger
    snapshotProvider = CalendarSnapshotProvider(logger: logger.child("snapshot_provider"))
    socketServer = CalendarSocketServer(
      socketPath: config.calendarAgentSocketPath,
      logger: logger.child("socket_server")
    )
  }

  /// Returns whether the calendar agent should run.
  var isEnabled: Bool {
    runtimeConfig.calendarAgentEnabled
  }

  /// Starts snapshot delivery and the calendar socket server.
  @discardableResult
  func start() -> Bool {
    guard isEnabled else {
      logger.info("calendar agent disabled in config")
      return false
    }

    logProcessStartup(
      processName: "calendar agent",
      configPath: runtimeConfig.configPath,
      socketPath: runtimeConfig.calendarAgentSocketPath,
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
