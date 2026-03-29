import EasyBarShared
import Foundation

@MainActor
final class AppController {
  private let runtimeConfig: SharedRuntimeConfig
  private let snapshotProvider = CalendarSnapshotProvider()
  private let socketServer: CalendarSocketServer

  init(config: SharedRuntimeConfig = .current) {
    runtimeConfig = config
    socketServer = CalendarSocketServer(socketPath: config.calendarAgentSocketPath)
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

  /// Logs one startup snapshot for the calendar agent.
  private func logStartup() {
    let bundle = Bundle.main
    let info = bundle.infoDictionary ?? [:]

    AgentLogger.info(
      "calendar agent startup version=\(info["CFBundleShortVersionString"] as? String ?? "unknown") build=\(info["CFBundleVersion"] as? String ?? "unknown") bundle_id=\(bundle.bundleIdentifier ?? "unknown") pid=\(ProcessInfo.processInfo.processIdentifier)"
    )
    AgentLogger.info("app bundle_path=\(bundle.bundleURL.path)")
    AgentLogger.info("app executable=\(bundle.executableURL?.path ?? "unknown")")
    AgentLogger.info(
      "config path=\(runtimeConfig.configPath)"
    )
    AgentLogger.info("socket path=\(runtimeConfig.calendarAgentSocketPath)")
    AgentLogger.info(
      "logging enabled=\(AgentLogger.fileLoggingEnabled) debug=\(AgentLogger.debugEnabled) path=\(AgentLogger.fileLoggingPath)"
    )
    AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
  }
}
