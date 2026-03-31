import EasyBarShared
import Foundation

final class NativeMonthCalendarStore: ObservableObject {

  static let shared = NativeMonthCalendarStore()

  @Published private(set) var snapshot: CalendarAgentSnapshot?
  @Published private(set) var sections: [NativeMonthCalendarPopupSection] = []
  @Published private(set) var events: [NativeMonthCalendarEvent] = []

  private let calendar = Calendar.current

  private var subscribedMonthRangeStart: Date?
  private var subscribedMonthRangeEnd: Date?

  private init() {}

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: CalendarAgentSnapshot) {
    Logger.debug(
      "month calendar popup applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
    )
    publish(snapshot: snapshot)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    Logger.debug("month calendar popup cleared")
    publish(snapshot: nil)
  }

  /// Returns all events overlapping one day.
  func eventsForDay(_ date: Date) -> [NativeMonthCalendarEvent] {
    let startOfDay = calendar.startOfDay(for: date)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      Logger.debug(
        "month calendar store eventsForDay failed to build end_of_day date=\(startOfDay)")
      return []
    }

    let matches = events.filter { event in
      event.startDate < endOfDay && event.endDate > startOfDay
    }

    Logger.debug(
      "month calendar store eventsForDay date=\(debugDate(startOfDay)) matches=\(matches.count)"
    )

    return matches
  }

  /// Returns all events overlapping the inclusive day range.
  func eventsInRange(from startDate: Date, to endDate: Date) -> [NativeMonthCalendarEvent] {
    let startOfRange = calendar.startOfDay(for: startDate)
    let endDayStart = calendar.startOfDay(for: endDate)

    guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDayStart) else {
      Logger.debug(
        "month calendar store eventsInRange failed to build end_of_range start=\(debugDate(startOfRange)) end=\(debugDate(endDayStart))"
      )
      return []
    }

    let matches = events.filter { event in
      event.startDate < endOfRange && event.endDate > startOfRange
    }

    Logger.debug(
      "month calendar store eventsInRange start=\(debugDate(startOfRange)) end=\(debugDate(endDayStart)) matches=\(matches.count)"
    )

    return matches
  }

  /// Returns whether one day has at least one event.
  func hasEvents(on date: Date) -> Bool {
    !eventsForDay(date).isEmpty
  }

  /// Prepares the subscribed month preload range for one visible month.
  ///
  /// The range always covers the previous, current, and next month relative to
  /// the visible month. Returns true when the caller should refresh the socket
  /// subscription because the active preload range changed.
  func prepareMonthSubscriptionRange(for visibleMonth: Date) -> Bool {
    let startOfVisibleMonth = startOfMonth(visibleMonth)

    guard
      let start = calendar.date(byAdding: .month, value: -1, to: startOfVisibleMonth),
      let afterNextMonth = calendar.date(byAdding: .month, value: 2, to: startOfVisibleMonth)
    else {
      return false
    }

    let normalizedStart = calendar.startOfDay(for: start)
    let normalizedEnd = calendar.startOfDay(for: afterNextMonth)

    let changed =
      subscribedMonthRangeStart != normalizedStart || subscribedMonthRangeEnd != normalizedEnd

    if changed {
      subscribedMonthRangeStart = normalizedStart
      subscribedMonthRangeEnd = normalizedEnd

      Logger.debug(
        "month calendar store prepared subscription range start=\(debugDate(normalizedStart)) end=\(debugDate(normalizedEnd))"
      )
    }

    return changed
  }

  /// Returns the currently prepared month preload range.
  func monthSubscriptionRange() -> (start: Date, end: Date)? {
    guard let subscribedMonthRangeStart, let subscribedMonthRangeEnd else { return nil }
    return (start: subscribedMonthRangeStart, end: subscribedMonthRangeEnd)
  }

  /// Publishes one calendar snapshot update on the main queue.
  private func publish(snapshot: CalendarAgentSnapshot?) {
    DispatchQueue.main.async {
      self.snapshot = snapshot
      self.sections = snapshot?.sections ?? []
      self.events = snapshot?.events ?? []

      Logger.debug(
        "month calendar store published snapshot_present=\(snapshot != nil) events=\(self.events.count) sections=\(self.sections.count)"
      )
    }
  }

  /// Returns the first day of one month.
  private func startOfMonth(_ date: Date) -> Date {
    let components = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: components) ?? calendar.startOfDay(for: date)
  }

  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
