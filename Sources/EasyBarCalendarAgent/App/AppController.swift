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
    snapshotProvider = CalendarSnapshotProvider(logger: logger)
    socketServer = CalendarSocketServer(
      socketPath: config.calendarAgentSocketPath,
      logger: logger
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

    logStartup()

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

  /// Logs one startup snapshot for the calendar agent.
  private func logStartup() {
    logProcessStartup(
      snapshot: makeProcessStartupSnapshot(
        processName: "calendar agent",
        configPath: runtimeConfig.configPath,
        socketSummary: "socket path=\(runtimeConfig.calendarAgentSocketPath)",
        loggingSummary:
          "logging enabled=\(logger.fileLoggingEnabled) debug=\(logger.debugEnabled) path=\(logger.fileLoggingPath)"
      ),
      write: logger.info
    )
    logger.info("debug logging=\(logger.debugEnabled)")
  }
}
