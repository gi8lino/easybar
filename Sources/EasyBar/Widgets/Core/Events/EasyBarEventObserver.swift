import Foundation

/// Small helper for observing typed EasyBar events in native widgets.
final class EasyBarEventObserver {
  private var task: Task<Void, Never>?

  /// Starts observing EasyBar events.
  ///
  /// The handler receives the already typed payload on the main actor.
  func start(handler: @escaping (EasyBarEventPayload) -> Void) {
    stop()

    task = Task {
      let stream = await EventHub.shared.subscribe()

      for await payload in stream {
        guard !Task.isCancelled else { break }

        await MainActor.run {
          handler(payload)
        }
      }
    }
  }

  /// Stops observing EasyBar events.
  func stop() {
    task?.cancel()
    task = nil
  }
}
