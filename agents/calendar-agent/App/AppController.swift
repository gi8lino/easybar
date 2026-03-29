import EasyBarShared
import Foundation

@MainActor
final class AppController {
  private let runtimeConfig: SharedRuntimeConfig
  private let snapshotProvider = CalendarSnapshotProvider()
  private let socketServer: CalendarSocketServer

  /// Builds the calendar agent controller from one runtime config.
  init(config: SharedRuntimeConfig = .current) {
    runtimeConfig = config
    socketServer = CalendarSocketServer(socketPath: config.calendarAgentSocketPath)
  }

  /// Starts logging, snapshot delivery, and the calendar socket server.
  func start() {
    AgentLogger.configure(using: runtimeConfig)
    logStartup()

    snapshotProvider.start { [weak self] in
      self?.socketServer.broadcastSnapshots()
    }

    socketServer.start(provider: snapshotProvider)
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
        loggingSummary: "logging enabled=\(AgentLogger.fileLoggingEnabled) debug=\(AgentLogger.debugEnabled) path=\(AgentLogger.fileLoggingPath)"
      ),
      write: AgentLogger.info
    )
    AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
  }
}
