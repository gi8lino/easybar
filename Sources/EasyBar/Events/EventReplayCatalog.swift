import Foundation

/// Replayable event definitions for new subscribers and runtime startup refreshes.
enum EventReplayCatalog {
  static let orderedInvalidations = EventStateInvalidation.allCases
  static let orderedEventNames = orderedInvalidations.map(\.eventName)

  /// Returns whether the given event name participates in replay caching.
  static func isReplayable(_ eventName: String) -> Bool {
    orderedEventNames.contains(eventName)
  }

  /// Returns replayable payloads for the requested event names in stable order.
  static func payloads(for eventNames: Set<String>) async -> [EasyBarEventPayload] {
    var payloads: [EasyBarEventPayload] = []

    for invalidation in orderedInvalidations where eventNames.contains(invalidation.eventName) {
      guard let payload = await invalidation.provider() else { continue }
      payloads.append(payload)
    }

    return payloads
  }
}
