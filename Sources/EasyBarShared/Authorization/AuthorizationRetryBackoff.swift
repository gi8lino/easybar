import Foundation

/// Schedules incremental authorization retries using Swift tasks.
public final class AuthorizationRetryBackoff: @unchecked Sendable {
  private struct State {
    var scheduledTask: Task<Void, Never>?
    var attemptIndex = 0
  }

  private let delays: [TimeInterval]
  private let logger: ProcessLogger
  private let state = LockedState(State())

  /// Builds one retry scheduler with incremental delays capped at the last value.
  public init(
    delays: [TimeInterval] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 60],
    logger: ProcessLogger
  ) {
    self.delays = delays
    self.logger = logger
  }

  /// Cancels any pending retry and resets the delay sequence.
  public func reset() {
    let task = state.withLock { state -> Task<Void, Never>? in
      let task = state.scheduledTask
      state.scheduledTask = nil
      state.attemptIndex = 0
      return task
    }

    task?.cancel()
  }

  /// Schedules the next retry attempt when none is currently pending.
  public func schedule(_ action: @escaping @Sendable () -> Void) {
    let scheduledDelay = state.withLock { state -> TimeInterval? in
      guard state.scheduledTask == nil else {
        return nil
      }

      let delay = delayForAttempt(state.attemptIndex)
      state.attemptIndex += 1
      return delay
    }

    guard let scheduledDelay else { return }

    logger.debug(
      "authorization retry scheduled",
      .field("delay", "\(scheduledDelay)"),
    )

    let nanoseconds = UInt64(max(scheduledDelay, 0) * 1_000_000_000)
    let task = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: nanoseconds)
      } catch {
        return
      }

      guard let self else { return }
      guard self.clearScheduledTask() else { return }

      await MainActor.run {
        action()
      }
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

  /// Returns the delay for one retry attempt.
  private func delayForAttempt(_ attemptIndex: Int) -> TimeInterval {
    guard !delays.isEmpty else {
      return 0
    }

    return delays[min(attemptIndex, delays.count - 1)]
  }

  /// Clears the current scheduled task after it has fired.
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
