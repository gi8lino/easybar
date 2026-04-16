import Foundation

/// Coalesces calendar-agent snapshot updates into a single app-wide calendar event.
final class CalendarAgentEventRelay {
  static let shared = CalendarAgentEventRelay()

  private let queue = DispatchQueue(label: "easybar.calendar-agent.event-relay")
  private var running = false
  private var generation: UInt64 = 0
  private var pendingWorkItem: DispatchWorkItem?

  private init() {}

  /// Activates the relay for runtime event delivery.
  func start() {
    queue.async {
      self.running = true
      self.generation &+= 1
    }
  }

  /// Cancels pending emissions and disables the relay.
  func stop() {
    queue.async {
      self.running = false
      self.generation &+= 1
      self.pendingWorkItem?.cancel()
      self.pendingWorkItem = nil
    }
  }

  /// Schedules one debounced `calendar_change` emission.
  ///
  /// Both month and upcoming calendar clients may receive snapshots for the same
  /// underlying EventKit change. This relay collapses those near-simultaneous
  /// updates into one app-wide event.
  func noteSnapshotUpdate() {
    queue.async { [weak self] in
      guard let self else { return }
      guard self.running else { return }

      let generation = self.generation

      self.pendingWorkItem?.cancel()

      let workItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        guard self.running, self.generation == generation else { return }

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
