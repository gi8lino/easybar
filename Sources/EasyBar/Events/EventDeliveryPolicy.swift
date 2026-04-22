import Foundation

/// Delivery and buffering policy for one event name.
enum EventDeliveryPolicy {
  case reliable
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
      return .reliable
    }
  }

  /// Returns whether one event should be delivered only to matching widget observers.
  static func routesDirectlyToWidgets(_ eventName: String) -> Bool {
    WidgetEvent(rawValue: eventName) != nil
  }

  /// Returns the default buffering policy for one subscription set.
  static func defaultBufferingPolicy(
    for eventNames: Set<String>?
  ) -> AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy {
    guard let eventNames, !eventNames.isEmpty else {
      return .bufferingNewest(32)
    }

    let reliableCount = eventNames.reduce(into: 0) { count, name in
      if forEventName(name) == .reliable {
        count += 1
      }
    }

    if reliableCount == 0 {
      return .bufferingNewest(1)
    }

    if reliableCount < eventNames.count {
      return .bufferingNewest(8)
    }

    return .bufferingNewest(32)
  }
}
