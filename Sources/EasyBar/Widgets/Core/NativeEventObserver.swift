import Foundation

/// Small helper for observing typed EasyBar events in native widgets.
final class EasyBarEventObserver {

    private var token: NSObjectProtocol?

    /// Starts observing EasyBar events.
    ///
    /// The handler receives the already typed payload.
    func start(handler: @escaping (EasyBarEventPayload) -> Void) {
        stop()

        token = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { notification in
            guard let payload = notification.object as? EasyBarEventPayload else {
                return
            }

            handler(payload)
        }
    }

    /// Stops observing EasyBar events.
    func stop() {
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }
}
