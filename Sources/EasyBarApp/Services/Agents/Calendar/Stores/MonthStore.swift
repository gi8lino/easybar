import EasyBarCalendarPresentation
import EasyBarCalendarUI
import EasyBarShared
import Foundation

/// Shared month-calendar snapshot store used by the native month popup.
final class NativeMonthCalendarStore: CalendarMonthPopupStore {
  static var shared = NativeMonthCalendarStore(
    logger: ProcessLogger(label: "easybar.bootstrap.month_store")
  )

  /// Configures the shared month-calendar store.
  static func bootstrap(logger: ProcessLogger) {
    shared = NativeMonthCalendarStore(logger: logger)
  }

  @Published private(set) var snapshot: EasyBarShared.CalendarAgentSnapshot?
  @Published private(set) var sections: [EasyBarShared.CalendarAgentSection] = []
  @Published private(set) var events: [EasyBarShared.CalendarAgentEvent] = []

  private var subscribedMonthRangeStart: Date?
  private var subscribedMonthRangeEnd: Date?
  private var focusedVisibleMonth: Date?
  private var subscribedMonthRadius: Int?

  let logger: ProcessLogger

  private init(
    logger: ProcessLogger
  ) {
    self.logger = logger
  }

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: EasyBarShared.CalendarAgentSnapshot) {
    logger.debug(
      "month calendar popup applied snapshot",
      .field("access_granted", "\(snapshot.accessGranted)"),
      .field("permission_state", "\(snapshot.permissionState)"),
      .field("events", "\(snapshot.events.count)"),
      .field("sections", "\(snapshot.sections.count)"),
    )
    publish(snapshot: snapshot)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    logger.debug("month calendar popup cleared")
    publish(snapshot: nil)
  }

  /// Returns all events overlapping the inclusive day range.
  func eventsInRange(from startDate: Date, to endDate: Date) -> [EasyBarShared.CalendarAgentEvent] {
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
    return !eventsForDay(date).isEmpty
  }

  /// Prepares the subscribed month preload range for one visible month and radius.
  func prepareMonthSubscriptionRange(for visibleMonth: Date, radius: Int, calendar: Calendar)
    -> Bool
  {
    let startOfVisibleMonth = CalendarMonthRangeBuilder.startOfMonth(visibleMonth, calendar: calendar)
    let normalizedRadius = max(radius, 0)
    let preparedRange = CalendarMonthRangeBuilder.subscriptionRange(
      for: startOfVisibleMonth,
      radius: normalizedRadius,
      calendar: calendar
    )

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

      logger.debug(
        "month calendar store prepared subscription range",
        .field("month", "\(debugDate(startOfVisibleMonth))"),
        .field("radius", "\(normalizedRadius)"),
        .field("start", "\(debugDate(preparedRange.start))"),
        .field("end", "\(debugDate(preparedRange.end))"),
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

      self.logger.debug(
        "month calendar store published",
        .field("snapshot_present", "\(snapshot != nil)"),
        .field("events", "\(self.events.count)"),
        .field("sections", "\(self.sections.count)"),
      )
    }

    if Thread.isMainThread {
      applyChange()
      return
    }

    DispatchQueue.main.async(execute: applyChange)
  }
  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
