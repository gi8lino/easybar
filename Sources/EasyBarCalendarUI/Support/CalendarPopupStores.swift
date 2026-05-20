import Combine
import EasyBarShared
import Foundation

/// Store interface required by the reusable month-calendar popup.
@MainActor
public protocol CalendarMonthPopupStore: ObservableObject {
  /// Latest snapshot returned by the calendar agent.
  var snapshot: CalendarAgentSnapshot? { get }
  /// Flat event list used by the month grid and agenda.
  var events: [CalendarAgentEvent] { get }

  /// Returns all events overlapping the inclusive day range.
  func eventsInRange(from startDate: Date, to endDate: Date) -> [CalendarAgentEvent]
  /// Returns whether one day has at least one event.
  func hasEvents(on date: Date) -> Bool
}

extension CalendarMonthPopupStore {
  /// Returns all events overlapping one calendar day.
  public func eventsForDay(_ date: Date) -> [CalendarAgentEvent] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)

    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      return []
    }

    return events.filter { event in
      event.startDate < endOfDay && event.endDate > startOfDay
    }
  }
}

/// Store interface required by the reusable upcoming-calendar popup.
@MainActor
public protocol CalendarUpcomingPopupStore: ObservableObject {
  /// Latest snapshot returned by the calendar agent.
  var snapshot: CalendarAgentSnapshot? { get }
  /// Flat event list used by the upcoming popup.
  var events: [CalendarAgentEvent] { get }
}
