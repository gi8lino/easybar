import Foundation

/// Shares the wake-triggered refresh observation used by app-side agent services.
final class AgentWakeRefreshController {
  private let label: String
  private let delay: TimeInterval
  private let eventObserver = EasyBarEventObserver()
  private let queue: DispatchQueue
  private var pendingWorkItem: DispatchWorkItem?

  init(label: String, delay: TimeInterval = 0.20) {
    self.label = label
    self.delay = delay
    queue = DispatchQueue(label: "easybar.\(label.replacingOccurrences(of: " ", with: "-")).wake")
  }

  /// Starts observing `system_woke` and schedules the refresh callback.
  func start(refresh: @escaping () -> Void) {
    eventObserver.start(eventNames: [AppEvent.systemWoke.rawValue]) { [weak self] payload in
      guard let self else { return }
      guard payload.appEvent == .systemWoke else { return }

      self.pendingWorkItem?.cancel()

      let workItem = DispatchWorkItem {
        easybarLog.debug("\(self.label) refreshing after system_woke")
        refresh()
      }

      self.pendingWorkItem = workItem
      self.queue.asyncAfter(deadline: .now() + self.delay, execute: workItem)
    }
  }

  /// Stops wake observation and cancels queued refresh work.
  func stop() {
    pendingWorkItem?.cancel()
    pendingWorkItem = nil
    eventObserver.stop()
  }
}
