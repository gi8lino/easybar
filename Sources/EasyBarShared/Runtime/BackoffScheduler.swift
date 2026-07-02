import Foundation

/// Schedules one retry action at a time using capped incremental delays.
///
/// Sendability is guarded by `LockedState`; pending task ownership and attempt
/// counters are only read or changed while holding the lock.
public final class BackoffScheduler: @unchecked Sendable {
  private struct State {
    var scheduledTask: Task<Void, Never>?
    var attemptIndex = 0
  }

  private let label: String
  private let delays: [TimeInterval]
  private let logger: ProcessLogger
  private let sleeper: any AsyncSleeper
  private let state = LockedState(State())

  /// Creates one capped backoff scheduler.
  public init(
    label: String,
    delays: [TimeInterval],
    logger: ProcessLogger,
    sleeper: any AsyncSleeper = TaskSleeper()
  ) {
    self.label = label
    self.delays = delays
    self.logger = logger
    self.sleeper = sleeper
  }

  /// Schedules the next backoff attempt when none is currently pending.
  public func schedule(_ action: @escaping @Sendable () -> Void) {
    schedule(after: nil, action)
  }

  /// Schedules one retry using an explicit delay without advancing the backoff sequence.
  public func schedule(after delayOverride: TimeInterval?, _ action: @escaping @Sendable () -> Void) {
    let scheduledDelay = state.withLock { state -> TimeInterval? in
      guard state.scheduledTask == nil else {
        return nil
      }

      if let delayOverride {
        return delayOverride
      }

      let delay = delayForAttempt(state.attemptIndex)
      state.attemptIndex += 1
      return delay
    }

    guard let scheduledDelay else { return }

    logger.warn(
      "\(label) scheduled",
      .field("delay", "\(scheduledDelay)")
    )

    let nanoseconds = UInt64(max(scheduledDelay, 0) * 1_000_000_000)
    let sleeper = sleeper
    let task = Task { [weak self] in
      do {
        try await sleeper.sleep(nanoseconds: nanoseconds)
      } catch {
        return
      }

      guard let self else { return }
      guard self.clearScheduledTask() else { return }
      action()
    }

    let shouldCancel = state.withLock { state -> Bool in
      guard state.scheduledTask == nil else { return true }
      state.scheduledTask = task
      return false
    }

    if shouldCancel {
      task.cancel()
    }
  }

  /// Cancels any pending retry and resets the delay sequence.
  public func cancel() {
    let task = state.withLock { state -> Task<Void, Never>? in
      let task = state.scheduledTask
      state.scheduledTask = nil
      state.attemptIndex = 0
      return task
    }

    task?.cancel()
  }

  /// Resets the delay sequence without touching any pending retry.
  public func resetDelay() {
    state.withLock { state in
      state.attemptIndex = 0
    }
  }

  private func delayForAttempt(_ attemptIndex: Int) -> TimeInterval {
    guard !delays.isEmpty else {
      return 0
    }

    return delays[min(attemptIndex, delays.count - 1)]
  }

  private func clearScheduledTask() -> Bool {
    state.withLock { state -> Bool in
      guard state.scheduledTask != nil else {
        return false
      }

      state.scheduledTask = nil
      return true
    }
  }
}
