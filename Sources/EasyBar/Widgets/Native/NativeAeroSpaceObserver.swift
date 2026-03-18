import Foundation

/// Small helper for observing AeroSpace state updates in native widgets.
final class NativeAeroSpaceObserver {

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
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
