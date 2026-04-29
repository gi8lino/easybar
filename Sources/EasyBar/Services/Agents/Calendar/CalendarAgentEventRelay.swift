import EasyBarShared
import Foundation

/// Coalesces calendar-agent snapshot updates into a single app-wide calendar event.
final class CalendarAgentEventRelay {
  private static var sharedInstance: CalendarAgentEventRelay?

  /// Returns the configured shared calendar-agent event relay.
  static var shared: CalendarAgentEventRelay {
    guard let sharedInstance else {
      fatalError(
        "CalendarAgentEventRelay.bootstrap(logger:) must be called before CalendarAgentEventRelay.shared"
      )
    }

    return sharedInstance
  }

  /// Configures the shared calendar-agent event relay.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = CalendarAgentEventRelay(logger: logger)
  }

  private let queue = DispatchQueue(label: "easybar.calendar-agent.event-relay")
  private let logger: ProcessLogger

  private var running = false
  private var generation: UInt64 = 0

  private lazy var scheduler = DebouncedActionScheduler(
    label: "calendar agent event relay",
    delay: 0.05,
    queue: queue,
    logger: logger.child("scheduler")
  )

  private init(logger: ProcessLogger) {
    self.logger = logger
  }

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
      self.scheduler.cancel()
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

      self.scheduler.schedule { [weak self] in
        guard let self else { return }
        guard self.running, self.generation == generation else { return }

        DispatchQueue.main.async {
          Task {
            await EventHub.shared.emit(.calendarChange)
          }
        }
      }
    }
  }
}
