import Foundation

/// Coalesces calendar-agent snapshot updates into a single app-wide calendar event.
final class CalendarAgentEventRelay {
  static let shared = CalendarAgentEventRelay()

  private var pendingWorkItem: DispatchWorkItem?

  private init() {}

  /// Schedules one debounced `calendar_change` emission.
  ///
  /// Both month and upcoming calendar clients may receive snapshots for the same
  /// underlying EventKit change. This relay collapses those near-simultaneous
  /// updates into one app-wide event.
  func noteSnapshotUpdate() {
    pendingWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      EventBus.shared.emit(.calendarChange)
    }

    pendingWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
  }
}
