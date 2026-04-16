import EasyBarShared
import Foundation

final class NativeMonthCalendarStore: ObservableObject {
  static let shared = NativeMonthCalendarStore()

  @Published private(set) var snapshot: EasyBarShared.CalendarAgentSnapshot?
  @Published private(set) var sections: [NativeMonthCalendarPopupSection] = []
  @Published private(set) var events: [NativeMonthCalendarEvent] = []

  private var subscribedMonthRangeStart: Date?
  private var subscribedMonthRangeEnd: Date?
  private var focusedVisibleMonth: Date?
  private var subscribedMonthRadius: Int?

  private init() {}

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: EasyBarShared.CalendarAgentSnapshot) {
    easybarLog.debug(
      "month calendar popup applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
    )
    publish(snapshot: snapshot)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    easybarLog.debug("month calendar popup cleared")
    publish(snapshot: nil)
  }

  /// Returns all events overlapping one day.
  func eventsForDay(_ date: Date) -> [NativeMonthCalendarEvent] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)

    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      return []
    }

    return events.filter { event in
      event.startDate < endOfDay && event.endDate > startOfDay
    }
  }

  /// Returns all events overlapping the inclusive day range.
  func eventsInRange(from startDate: Date, to endDate: Date) -> [NativeMonthCalendarEvent] {
    let calendar = Calendar.current
    let startOfRange = calendar.startOfDay(for: startDate)
    let endDayStart = calendar.startOfDay(for: endDate)

    guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDayStart) else {
      return []
    }

    return events.filter { event in
      event.startDate < endOfRange && event.endDate > startOfRange
    }
  }

  /// Returns whether one day has at least one event.
  func hasEvents(on date: Date) -> Bool {
    !eventsForDay(date).isEmpty
  }

  /// Prepares the subscribed month preload range for one visible month and radius.
  func prepareMonthSubscriptionRange(for visibleMonth: Date, radius: Int, calendar: Calendar)
    -> Bool
  {
    let startOfVisibleMonth = startOfMonth(visibleMonth, calendar: calendar)
    let normalizedRadius = max(radius, 0)

    let preparedRange: DateInterval?

    if normalizedRadius == 0 {
      preparedRange = visibleGridRange(for: startOfVisibleMonth, calendar: calendar)
    } else {
      guard
        let start = calendar.date(
          byAdding: .month,
          value: -normalizedRadius,
          to: startOfVisibleMonth
        ),
        let afterEndMonth = calendar.date(
          byAdding: .month,
          value: normalizedRadius + 1,
          to: startOfVisibleMonth
        )
      else {
        return false
      }

      let normalizedStart = calendar.startOfDay(for: start)
      let normalizedEnd = calendar.startOfDay(for: afterEndMonth)
      preparedRange = DateInterval(start: normalizedStart, end: normalizedEnd)
    }

    guard let preparedRange else { return false }

    let changed =
      subscribedMonthRangeStart != preparedRange.start
      || subscribedMonthRangeEnd != preparedRange.end
      || focusedVisibleMonth != startOfVisibleMonth
      || subscribedMonthRadius != normalizedRadius

    if changed {
      subscribedMonthRangeStart = preparedRange.start
      subscribedMonthRangeEnd = preparedRange.end
      focusedVisibleMonth = startOfVisibleMonth
      subscribedMonthRadius = normalizedRadius

      easybarLog.debug(
        "month calendar store prepared subscription range month=\(debugDate(startOfVisibleMonth)) radius=\(normalizedRadius) start=\(debugDate(preparedRange.start)) end=\(debugDate(preparedRange.end))"
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
  private func publish(snapshot: EasyBarShared.CalendarAgentSnapshot?) {
    let applyChange = {
      self.snapshot = snapshot
      self.sections = snapshot?.sections ?? []
      self.events = snapshot?.events ?? []

      easybarLog.debug(
        "month calendar store published snapshot_present=\(snapshot != nil) events=\(self.events.count) sections=\(self.sections.count)"
      )
    }

    if Thread.isMainThread {
      applyChange()
      return
    }

    DispatchQueue.main.async(execute: applyChange)
  }

  /// Returns the first day of one month.
  private func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
    let components = calendar.dateComponents([.year, .month], from: date)
    return calendar.date(from: components) ?? calendar.startOfDay(for: date)
  }

  /// Returns the exact displayed grid range for one visible month.
  private func visibleGridRange(for visibleMonth: Date, calendar: Calendar) -> DateInterval? {
    let monthStart = startOfMonth(visibleMonth, calendar: calendar)

    guard
      let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart),
      let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
      let firstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
      let lastVisibleDay = calendar.date(byAdding: .day, value: -1, to: monthEnd),
      let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastVisibleDay)
    else {
      return nil
    }

    return DateInterval(
      start: calendar.startOfDay(for: firstWeek.start),
      end: calendar.startOfDay(for: lastWeek.end)
    )
  }

  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
