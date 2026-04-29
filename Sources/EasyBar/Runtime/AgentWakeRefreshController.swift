import EasyBarShared
import Foundation

/// Shares the wake-triggered refresh observation used by app-side agent services.
final class AgentWakeRefreshController {
  private let label: String
  private let delay: TimeInterval
  private let logger: ProcessLogger
  private let eventObserver = EasyBarEventObserver()

  private lazy var scheduler = DebouncedActionScheduler(
    label: "\(label) wake refresh",
    delay: delay,
    queue: DispatchQueue(
      label: "easybar.\(label.replacingOccurrences(of: " ", with: "-")).wake"
    ),
    logger: logger.child("scheduler")
  )

  init(
    label: String,
    delay: TimeInterval = 0.20,
    logger: ProcessLogger
  ) {
    self.label = label
    self.delay = delay
    self.logger = logger
  }

  /// Starts observing `system_woke` and schedules the refresh callback.
  func start(refresh: @escaping () -> Void) {
    eventObserver.start(eventNames: [AppEvent.systemWoke.rawValue]) { [weak self] payload in
      guard let self else { return }
      guard payload.appEvent == .systemWoke else { return }

      self.scheduler.schedule { [weak self] in
        guard let self else { return }

        self.logger.debug("\(self.label) refreshing after system_woke")
        refresh()
      }
    }
  }

  /// Stops wake observation and cancels queued refresh work.
  func stop() {
    scheduler.cancel()
    eventObserver.stop()
  }
}
