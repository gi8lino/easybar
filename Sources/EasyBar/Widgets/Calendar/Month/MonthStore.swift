import EasyBarShared
import Foundation

final class NativeMonthCalendarStore: ObservableObject {
  static let shared = NativeMonthCalendarStore()

  @Published private(set) var snapshot: EasyBarShared.CalendarAgentSnapshot?
  @Published private(set) var sections: [NativeMonthCalendarPopupSection] = []
  @Published private(set) var events: [NativeMonthCalendarEvent] = []

  private let calendar = Calendar.current

  private var subscribedMonthRangeStart: Date?
  private var subscribedMonthRangeEnd: Date?
  private var focusedVisibleMonth: Date?
  private var subscribedMonthRadius: Int?

  private init() {}

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: EasyBarShared.CalendarAgentSnapshot) {
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
  ///
  /// This method is used frequently during SwiftUI rendering, so it should stay
  /// free of debug logging to avoid noisy output and unnecessary overhead while
  /// typing or hovering in the popup.
  func eventsForDay(_ date: Date) -> [NativeMonthCalendarEvent] {
    let startOfDay = calendar.startOfDay(for: date)

    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      return []
    }

    return events.filter { event in
      event.startDate < endOfDay && event.endDate > startOfDay
    }
  }

  /// Returns all events overlapping the inclusive day range.
  ///
  /// This method is also used from view updates, so it intentionally avoids
  /// debug logging for the same reason as `eventsForDay(_:)`.
  func eventsInRange(from startDate: Date, to endDate: Date) -> [NativeMonthCalendarEvent] {
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
  ///
  /// Radius `0` means the visible month only, `1` adds previous and next month,
  /// and larger values expand outward symmetrically. Returns true when the
  /// active preload range changed.
  func prepareMonthSubscriptionRange(for visibleMonth: Date, radius: Int) -> Bool {
    let startOfVisibleMonth = startOfMonth(visibleMonth)
    let normalizedRadius = max(radius, 0)

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

    let changed =
      subscribedMonthRangeStart != normalizedStart
      || subscribedMonthRangeEnd != normalizedEnd
      || focusedVisibleMonth != startOfVisibleMonth
      || subscribedMonthRadius != normalizedRadius

    if changed {
      subscribedMonthRangeStart = normalizedStart
      subscribedMonthRangeEnd = normalizedEnd
      focusedVisibleMonth = startOfVisibleMonth
      subscribedMonthRadius = normalizedRadius

      Logger.debug(
        "month calendar store prepared subscription range month=\(debugDate(startOfVisibleMonth)) radius=\(normalizedRadius) start=\(debugDate(normalizedStart)) end=\(debugDate(normalizedEnd))"
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
