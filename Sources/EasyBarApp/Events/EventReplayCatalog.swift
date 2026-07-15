import Foundation

/// Replayable event definitions for new subscribers and runtime startup refreshes.
enum EventReplayCatalog {
  /// Replayable invalidations in stable emission order.
  static let orderedInvalidations = EventStateInvalidation.allCases
  /// Replayable event names in stable emission order.
  static let orderedEventNames = orderedInvalidations.map(\.eventName)

  /// Returns whether the given event name participates in replay caching.
  static func isReplayable(_ eventName: String) -> Bool {
    return orderedEventNames.contains(eventName)
  }

  /// Returns replayable payloads for the requested event names in stable order.
  static func payloads(for eventNames: Set<String>) async -> [EasyBarEventPayload] {
    var payloads: [EasyBarEventPayload] = []

    for invalidation in orderedInvalidations where eventNames.contains(invalidation.eventName) {
      guard let payload = await invalidation.currentPayload() else { continue }

      payloads.append(payload)
    }

    return payloads
  }
}
