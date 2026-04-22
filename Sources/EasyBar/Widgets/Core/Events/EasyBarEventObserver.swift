import Foundation

/// Small helper for observing typed EasyBar events in native widgets.
final class EasyBarEventObserver {
  private var task: Task<Void, Never>?

  /// Starts observing a filtered subset of EasyBar events.
  ///
  /// The handler receives the already typed payload on the main actor.
  func start(
    eventNames: Set<String>,
    widgetTargetIDs: Set<String>? = nil,
    replayLatest: Bool = false,
    bufferingPolicy: AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy? = nil,
    handler: @escaping (EasyBarEventPayload) -> Void
  ) {
    start(
      eventNames: Optional(eventNames),
      widgetTargetIDs: widgetTargetIDs,
      replayLatest: replayLatest,
      bufferingPolicy: bufferingPolicy,
      handler: handler
    )
  }

  /// Starts observing EasyBar events.
  ///
  /// The handler receives the already typed payload on the main actor.
  func start(handler: @escaping (EasyBarEventPayload) -> Void) {
    start(
      eventNames: nil,
      widgetTargetIDs: nil,
      replayLatest: false,
      bufferingPolicy: nil,
      handler: handler
    )
  }

  /// Starts observing EasyBar events with an optional event-name filter.
  ///
  /// The handler receives the already typed payload on the main actor.
  private func start(
    eventNames: Set<String>?,
    widgetTargetIDs: Set<String>?,
    replayLatest: Bool,
    bufferingPolicy: AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy?,
    handler: @escaping (EasyBarEventPayload) -> Void
  ) {
    stop()

    task = Task {
      let stream = await EventHub.shared.subscribe(
        eventNames: eventNames,
        widgetTargetIDs: widgetTargetIDs,
        replayLatest: replayLatest,
        bufferingPolicy: bufferingPolicy
      )

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
