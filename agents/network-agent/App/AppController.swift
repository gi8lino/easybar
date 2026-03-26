import Foundation
import EasyBarShared

@MainActor
final class AppController {
    private let snapshotProvider = NetworkSnapshotProvider()
    private let socketServer = NetworkSocketServer()

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

    /// Logs one startup snapshot for the network agent.
    private func logStartup() {
        let bundle = Bundle.main
        let info = bundle.infoDictionary ?? [:]

        AgentLogger.info("network agent startup version=\(info["CFBundleShortVersionString"] as? String ?? "unknown") build=\(info["CFBundleVersion"] as? String ?? "unknown") bundle_id=\(bundle.bundleIdentifier ?? "unknown") pid=\(ProcessInfo.processInfo.processIdentifier)")
        AgentLogger.info("app bundle_path=\(bundle.bundleURL.path)")
        AgentLogger.info("app executable=\(bundle.executableURL?.path ?? "unknown")")
        AgentLogger.info("config path=\(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/easybar/config.toml").path)")
        AgentLogger.info("socket path=\(defaultNetworkAgentSocketPath()) refresh_interval_seconds=\(defaultNetworkAgentRefreshIntervalSeconds())")
        AgentLogger.info("debug logging=\(AgentLogger.debugEnabled)")
    }
}
