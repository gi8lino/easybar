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

  /// Returns whether the calendar agent should run.
  var isEnabled: Bool {
    runtimeConfig.calendarAgentEnabled
  }

  /// Starts logging, snapshot delivery, and the calendar socket server.
  @discardableResult
  func start() -> Bool {
    AgentLogger.configure(using: runtimeConfig)
    guard isEnabled else {
      AgentLogger.info("calendar agent disabled in config")
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
        loggingSummary: "logging enabled=\(AgentLogger.fileLoggingEnabled) debug=\(AgentLogger.debugEnabled) path=\(AgentLogger.fileLoggingPath)"
      ),
      write: AgentLogger.info
    )
    AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
  }
}
