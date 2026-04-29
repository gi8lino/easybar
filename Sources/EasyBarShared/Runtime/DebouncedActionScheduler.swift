import Foundation

/// Schedules one replaceable delayed action on a dispatch queue.
public final class DebouncedActionScheduler {
  private let label: String?
  private let delay: TimeInterval
  private let queue: DispatchQueue
  private let logger: ProcessLogger

  private let lock = NSLock()

  private var pendingWorkItem: DispatchWorkItem?
  private var generation: UInt64 = 0

  /// Creates one debounced scheduler.
  public init(
    label: String? = nil,
    delay: TimeInterval,
    queue: DispatchQueue = .main,
    logger: ProcessLogger
  ) {
    self.label = label
    self.delay = delay
    self.queue = queue
    self.logger = logger
  }

  /// Replaces any pending action with a new delayed action.
  public func schedule(_ action: @escaping () -> Void) {
    let scheduledGeneration = nextGeneration()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard self.finishScheduledAction(generation: scheduledGeneration) else { return }

      action()
    }

    lock.lock()
    pendingWorkItem?.cancel()
    pendingWorkItem = workItem
    lock.unlock()

    if let label {
      logger.debug("\(label) scheduled", .field("delay", delay))
    }

    queue.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  /// Cancels any pending action.
  public func cancel() {
    lock.lock()

    generation &+= 1
    pendingWorkItem?.cancel()
    pendingWorkItem = nil

    lock.unlock()
  }

  /// Advances and returns the scheduler generation.
  private func nextGeneration() -> UInt64 {
    lock.lock()
    defer { lock.unlock() }

    generation &+= 1
    return generation
  }

  /// Clears the pending action if it is still the currently scheduled generation.
  private func finishScheduledAction(generation scheduledGeneration: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard generation == scheduledGeneration else {
      return false
    }

    pendingWorkItem = nil
    return true
  }
}
