import Foundation

/// Small helper for observing AeroSpace state updates in native widgets.
final class AeroSpaceUpdateObserver {

    private var token: NSObjectProtocol?

    /// Starts observing AeroSpace updates.
    func start(handler: @escaping () -> Void) {
        stop()

        token = NotificationCenter.default.addObserver(
            forName: .easyBarAeroSpaceDidUpdate,
            object: nil,
            queue: .main
        ) { _ in
            handler()
        }
    }

    /// Stops observing AeroSpace updates.
    func stop() {
        guard let token else { return }
        NotificationCenter.default.removeObserver(token)
        self.token = nil
    }
}
