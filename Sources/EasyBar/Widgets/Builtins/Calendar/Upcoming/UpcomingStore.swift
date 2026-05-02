import EasyBarShared
import Foundation

/// Shared upcoming-calendar snapshot store used by the native upcoming popup.
@MainActor
final class NativeUpcomingCalendarStore: ObservableObject {
  private static var sharedInstance: NativeUpcomingCalendarStore?

  static var shared: NativeUpcomingCalendarStore {
    guard let sharedInstance else {
      fatalError(
        "NativeUpcomingCalendarStore.bootstrap(logger:) must be called before NativeUpcomingCalendarStore.shared"
      )
    }

    return sharedInstance
  }

  /// Configures the shared upcoming-calendar store.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = NativeUpcomingCalendarStore(logger: logger)
  }

  @Published private(set) var snapshot: EasyBarShared.CalendarAgentSnapshot?
  @Published private(set) var events: [EasyBarShared.CalendarAgentEvent] = []

  private let calendar = Calendar.current
  let logger: ProcessLogger

  private init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: EasyBarShared.CalendarAgentSnapshot) {
    logger.debug(
      "upcoming calendar popup applied snapshot",
      .field("access_granted", "\(snapshot.accessGranted)"),
      .field("permission_state", "\(snapshot.permissionState)"),
      .field("events", "\(snapshot.events.count)"),
    )
    publish(snapshot: snapshot)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    logger.debug("upcoming calendar popup cleared")
    publish(snapshot: nil)
  }

  /// Returns all events overlapping one day.
  func overlappingEvents(on date: Date) -> [EasyBarShared.CalendarAgentEvent] {
    let startOfDay = calendar.startOfDay(for: date)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      logger.debug(
        "upcoming calendar store overlappingEvents(on:) failed",
        .field("date", "\(startOfDay)"),
      )
      return []
    }

    let matches = events.filter { event in
      event.startDate < endOfDay && event.endDate > startOfDay
    }

    logger.debug(
      "upcoming calendar store overlappingEvents(on:)",
      .field("date", "\(debugDate(startOfDay))"),
      .field("matches", "\(matches.count)"),
    )

    return matches
  }

  /// Returns all events overlapping the inclusive day range.
  func overlappingEvents(from startDate: Date, to endDate: Date) -> [EasyBarShared
    .CalendarAgentEvent]
  {
    let startOfRange = calendar.startOfDay(for: startDate)
    let endDayStart = calendar.startOfDay(for: endDate)

    guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDayStart) else {
      logger.debug(
        "upcoming calendar store overlappingEvents(from:to:) failed",
        .field("start", "\(debugDate(startOfRange))"),
        .field("end", "\(debugDate(endDayStart))"),
      )
      return []
    }

    let matches = events.filter { event in
      event.startDate < endOfRange && event.endDate > startOfRange
    }

    logger.debug(
      "upcoming calendar store overlappingEvents(from:to:)",
      .field("start", "\(debugDate(startOfRange))"),
      .field("end", "\(debugDate(endDayStart))"),
      .field("matches", "\(matches.count)"),
    )

    return matches
  }

  /// Returns whether one day has at least one event.
  func hasEvents(on date: Date) -> Bool {
    return !overlappingEvents(on: date).isEmpty
  }

  /// Publishes one calendar snapshot update.
  private func publish(snapshot: EasyBarShared.CalendarAgentSnapshot?) {
    self.snapshot = snapshot
    self.events = snapshot?.events ?? []

    logger.debug(
      "upcoming calendar store published",
      .field("snapshot_present", "\(snapshot != nil)"),
      .field("events", "\(self.events.count)"),
    )
  }

  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
