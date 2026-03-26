import Foundation
import EasyBarShared

@MainActor
final class AppController {
    private let snapshotProvider = CalendarSnapshotProvider()
    private let socketServer = CalendarSocketServer()

    func start() {
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

        AgentLogger.info("calendar agent startup version=\(info["CFBundleShortVersionString"] as? String ?? "unknown") build=\(info["CFBundleVersion"] as? String ?? "unknown") bundle_id=\(bundle.bundleIdentifier ?? "unknown") pid=\(ProcessInfo.processInfo.processIdentifier)")
        AgentLogger.info("app bundle_path=\(bundle.bundleURL.path)")
        AgentLogger.info("app executable=\(bundle.executableURL?.path ?? "unknown")")
        AgentLogger.info("config path=\(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/easybar/config.toml").path)")
        AgentLogger.info("socket path=\(defaultCalendarAgentSocketPath())")
        AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
    }
}
