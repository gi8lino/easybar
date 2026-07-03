import Foundation

/// Schedules incremental authorization retries using Swift tasks.
///
/// Sendability is guarded by `LockedState`; retry task ownership and attempt
/// counters are only read or changed while holding the lock.
public final class AuthorizationRetryBackoff: @unchecked Sendable {
  private struct State {
    var scheduledTask: Task<Void, Never>?
    var scheduledID: UInt64?
    var nextScheduledID: UInt64 = 1
    var attemptIndex = 0
  }

  private let delays: [TimeInterval]
  private let logger: ProcessLogger
  private let sleeper: any AsyncSleeper
  private let state = LockedState(State())

  /// Builds one retry scheduler with incremental delays capped at the last value.
  public init(
    delays: [TimeInterval] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 60],
    logger: ProcessLogger,
    sleeper: any AsyncSleeper = TaskSleeper()
  ) {
    self.delays = delays
    self.logger = logger
    self.sleeper = sleeper
  }

  /// Cancels any pending retry and resets the delay sequence.
  public func reset() {
    let task = state.withLock { state -> Task<Void, Never>? in
      let task = state.scheduledTask
      state.scheduledTask = nil
      state.scheduledID = nil
      state.attemptIndex = 0
      return task
    }

    task?.cancel()
  }

  /// Schedules the next retry attempt when none is currently pending.
  public func schedule(_ action: @escaping @Sendable () -> Void) {
    let scheduled = state.withLock { state -> (id: UInt64, delay: TimeInterval)? in
      guard state.scheduledID == nil else {
        return nil
      }

      let scheduledID = state.nextScheduledID
      state.nextScheduledID += 1
      state.scheduledID = scheduledID

      let delay = delayForAttempt(state.attemptIndex)
      state.attemptIndex += 1
      return (scheduledID, delay)
    }

    guard let scheduled else { return }

    logger.debug(
      "authorization retry scheduled",
      .field("delay", "\(scheduled.delay)"),
    )

    let nanoseconds = clampedSleepNanoseconds(from: scheduled.delay)
    let sleeper = sleeper
    let scheduledID = scheduled.id
    let task = Task { [weak self] in
      do {
        try await sleeper.sleep(nanoseconds: nanoseconds)
      } catch {
        return
      }

      guard let self else { return }
      guard self.clearScheduledTask(id: scheduledID) else { return }

      await MainActor.run {
        action()
      }
    }

    let shouldCancel = state.withLock { state -> Bool in
      guard state.scheduledID == scheduledID else { return true }
      state.scheduledTask = task
      return false
    }

    if shouldCancel {
      task.cancel()
    }
  }

  /// Returns the delay for one retry attempt.
  private func delayForAttempt(_ attemptIndex: Int) -> TimeInterval {
    guard !delays.isEmpty else {
      return 0
    }

    return delays[min(attemptIndex, delays.count - 1)]
  }

  /// Clears the current scheduled task after it has fired.
  private func clearScheduledTask(id: UInt64) -> Bool {
    state.withLock { state -> Bool in
      guard state.scheduledID == id else {
        return false
      }

      state.scheduledTask = nil
      state.scheduledID = nil
      return true
    }
  }
}
