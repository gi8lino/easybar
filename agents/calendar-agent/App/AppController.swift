import Foundation

@MainActor
final class AppController {
    private let snapshotProvider = CalendarSnapshotProvider()
    private let socketServer = CalendarSocketServer()

    func start() {
        snapshotProvider.start { [weak self] in
            self?.socketServer.broadcastSnapshots()
        }

        socketServer.start(provider: snapshotProvider)
    }

    func stop() {
        socketServer.stop()
        snapshotProvider.stop()
    }
}
