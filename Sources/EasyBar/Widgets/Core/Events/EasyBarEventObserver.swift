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
      queue: nil
    ) { notification in
      guard let payload = notification.object as? EasyBarEventPayload else {
        return
      }

      if Thread.isMainThread {
        handler(payload)
        return
      }

      DispatchQueue.main.async {
        handler(payload)
      }
    }
  }

  /// Stops observing EasyBar events.
  func stop() {
    guard let token else { return }
    NotificationCenter.default.removeObserver(token)
    self.token = nil
  }
}
