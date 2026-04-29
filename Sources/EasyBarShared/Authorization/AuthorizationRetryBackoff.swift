import Foundation

/// Schedules incremental authorization retries on one dispatch queue.
public final class AuthorizationRetryBackoff {
  private let delays: [TimeInterval]
  private let queue: DispatchQueue
  private let logger: ProcessLogger
  private let lock = NSLock()

  private var scheduledWorkItem: DispatchWorkItem?
  private var attemptIndex = 0

  /// Builds one retry scheduler with incremental delays capped at the last value.
  public init(
    delays: [TimeInterval] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 60],
    queue: DispatchQueue = .main,
    logger: ProcessLogger
  ) {
    self.delays = delays
    self.queue = queue
    self.logger = logger
  }

  /// Cancels any pending retry and resets the delay sequence.
  public func reset() {
    let workItem = withLock { () -> DispatchWorkItem? in
      let workItem = scheduledWorkItem
      scheduledWorkItem = nil
      attemptIndex = 0
      return workItem
    }

    workItem?.cancel()
  }

  /// Schedules the next retry attempt when none is currently pending.
  public func schedule(_ action: @escaping () -> Void) {
    var workItem: DispatchWorkItem?

    let scheduledDelay = withLock { () -> TimeInterval? in
      guard scheduledWorkItem == nil else {
        return nil
      }

      let delay = delayForCurrentAttempt()
      attemptIndex += 1

      let nextWorkItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        guard self.clearScheduledWorkItem() else { return }

        action()
      }

      scheduledWorkItem = nextWorkItem
      workItem = nextWorkItem

      return delay
    }

    guard let scheduledDelay, let workItem else { return }

    logger.debug(
      "authorization retry scheduled",
      .field("delay", "\(scheduledDelay)"),
    )
    queue.asyncAfter(deadline: .now() + scheduledDelay, execute: workItem)
  }

  /// Returns the delay for the current retry attempt.
  private func delayForCurrentAttempt() -> TimeInterval {
    guard !delays.isEmpty else {
      return 0
    }

    return delays[min(attemptIndex, delays.count - 1)]
  }

  /// Clears the current scheduled item after it has fired.
  private func clearScheduledWorkItem() -> Bool {
    withLock {
      guard scheduledWorkItem != nil else {
        return false
      }

      scheduledWorkItem = nil
      return true
    }
  }

  /// Runs one closure while holding the backoff lock.
  private func withLock<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }

    return body()
  }
}
