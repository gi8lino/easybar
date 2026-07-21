import Foundation

/// Delivery and buffering policy for one event name.
enum EventDeliveryPolicy {
  /// Preserve every event in enqueue order.
  case mustDeliver
  /// Prefer the newest value when events arrive faster than consumers read.
  case coalescing

  /// Returns the policy for one event name.
  static func forEventName(_ eventName: String) -> EventDeliveryPolicy {
    switch eventName {
    case AppEvent.secondTick.rawValue,
      AppEvent.intervalTick.rawValue,
      WidgetEvent.mouseEntered.rawValue,
      WidgetEvent.mouseExited.rawValue,
      WidgetEvent.mouseScrolled.rawValue,
      WidgetEvent.sliderPreview.rawValue:
      return .coalescing
    default:
      return .mustDeliver
    }
  }

  /// Returns whether one event should be delivered only to matching widget observers.
  static func routesDirectlyToWidgets(_ eventName: String) -> Bool {
    return WidgetEvent(rawValue: eventName) != nil
  }

  /// Returns the default buffering policy for one filtered subscription set.
  ///
  /// Streams that include any must-deliver event are unbounded so action events
  /// cannot be displaced by newer state. Callers that observe every event must
  /// select their buffering contract explicitly through `subscribeAll`.
  static func defaultBufferingPolicy(
    for eventNames: Set<String>
  ) -> AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy {
    guard !eventNames.isEmpty else {
      return .unbounded
    }

    let containsMustDeliverEvent = eventNames.contains { eventName in
      forEventName(eventName) == .mustDeliver
    }

    return containsMustDeliverEvent ? .unbounded : .bufferingNewest(1)
  }
}

/// Aggregated subscriber-buffer overflow for one event class.
struct EventBackpressureSample: Hashable, Sendable {
  let name: String
  let count: Int
  let coalesced: Bool
}
