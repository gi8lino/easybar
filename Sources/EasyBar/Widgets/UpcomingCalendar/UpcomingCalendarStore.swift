import EasyBarShared
import Foundation

final class NativeUpcomingCalendarStore: ObservableObject {

  static let shared = NativeUpcomingCalendarStore()

  @Published private(set) var snapshot: CalendarAgentSnapshot?
  @Published private(set) var sections: [NativeUpcomingCalendarPopupSection] = []
  @Published private(set) var events: [NativeUpcomingCalendarEvent] = []

  private let calendar = Calendar.current

  private init() {}

  /// Applies one calendar snapshot to the shared store.
  func apply(snapshot: CalendarAgentSnapshot) {
    Logger.debug(
      "upcoming calendar popup applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
    )
    publish(snapshot: snapshot)
  }

  /// Clears the current calendar snapshot.
  func clear() {
    Logger.debug("upcoming calendar popup cleared")
    publish(snapshot: nil)
  }

  /// Returns all events overlapping one day.
  func overlappingEvents(on date: Date) -> [NativeUpcomingCalendarEvent] {
    let startOfDay = calendar.startOfDay(for: date)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
      Logger.debug(
        "upcoming calendar store overlappingEvents(on:) failed date=\(startOfDay)")
      return []
    }

    let matches = events.filter { event in
      event.startDate < endOfDay && event.endDate > startOfDay
    }

    Logger.debug(
      "upcoming calendar store overlappingEvents(on:) date=\(debugDate(startOfDay)) matches=\(matches.count)"
    )

    return matches
  }

  /// Returns all events overlapping the inclusive day range.
  func overlappingEvents(from startDate: Date, to endDate: Date) -> [NativeUpcomingCalendarEvent] {
    let startOfRange = calendar.startOfDay(for: startDate)
    let endDayStart = calendar.startOfDay(for: endDate)

    guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDayStart) else {
      Logger.debug(
        "upcoming calendar store overlappingEvents(from:to:) failed start=\(debugDate(startOfRange)) end=\(debugDate(endDayStart))"
      )
      return []
    }

    let matches = events.filter { event in
      event.startDate < endOfRange && event.endDate > startOfRange
    }

    Logger.debug(
      "upcoming calendar store overlappingEvents(from:to:) start=\(debugDate(startOfRange)) end=\(debugDate(endDayStart)) matches=\(matches.count)"
    )

    return matches
  }

  /// Returns whether one day has at least one event.
  func hasEvents(on date: Date) -> Bool {
    !overlappingEvents(on: date).isEmpty
  }

  /// Publishes one calendar snapshot update on the main queue.
  private func publish(snapshot: CalendarAgentSnapshot?) {
    DispatchQueue.main.async {
      self.snapshot = snapshot
      self.sections = snapshot?.sections ?? []
      self.events = snapshot?.events ?? []

      Logger.debug(
        "upcoming calendar store published snapshot_present=\(snapshot != nil) events=\(self.events.count) sections=\(self.sections.count)"
      )
    }
  }

  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
