import Foundation

/// Coalesces calendar-agent snapshot updates into a single app-wide calendar event.
final class CalendarAgentEventRelay {
  static let shared = CalendarAgentEventRelay()

  private let queue = DispatchQueue(label: "easybar.calendar-agent.event-relay")
  private var pendingWorkItem: DispatchWorkItem?

  private init() {}

  /// Schedules one debounced `calendar_change` emission.
  ///
  /// Both month and upcoming calendar clients may receive snapshots for the same
  /// underlying EventKit change. This relay collapses those near-simultaneous
  /// updates into one app-wide event.
  func noteSnapshotUpdate() {
    queue.async { [weak self] in
      guard let self else { return }

      self.pendingWorkItem?.cancel()

      let workItem = DispatchWorkItem {
        DispatchQueue.main.async {
          Task {
            await EventHub.shared.emit(.calendarChange)
          }
        }
      }

      self.pendingWorkItem = workItem
      self.queue.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }
  }
}
