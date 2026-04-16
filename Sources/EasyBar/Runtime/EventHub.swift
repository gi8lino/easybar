import Foundation

/// High-level runtime events used by the app coordinator.
///
/// This sits above the legacy widget/event bus layer so the runtime can use
/// actor-based event flow without forcing all existing widgets to migrate at once.
enum RuntimeEvent: Sendable {
  case started
  case stopped

  case configFileChanged
  case configReloaded
  case configReloadFailed(message: String)

  case luaRuntimeRestarted
  case runtimeRefreshed

  case ipcCommand(IPC.Command)
}

/// Actor-based event hub used by runtime services.
///
/// Multiple runtime components can subscribe through `AsyncStream`.
actor EventHub {
  static let shared = EventHub()

  private var continuations: [UUID: AsyncStream<RuntimeEvent>.Continuation] = [:]

  /// Returns a stream of runtime events for one subscriber.
  func subscribe() -> AsyncStream<RuntimeEvent> {
    let id = UUID()

    return AsyncStream { continuation in
      continuations[id] = continuation

      continuation.onTermination = { [weak self] _ in
        Task {
          await self?.removeContinuation(id: id)
        }
      }
    }
  }

  /// Publishes one runtime event to all subscribers.
  func publish(_ event: RuntimeEvent) {
    for continuation in continuations.values {
      continuation.yield(event)
    }
  }

  /// Finishes all active subscriptions.
  func finish() {
    for continuation in continuations.values {
      continuation.finish()
    }

    continuations.removeAll()
  }

  /// Removes one terminated continuation.
  private func removeContinuation(id: UUID) {
    continuations.removeValue(forKey: id)
  }
}
