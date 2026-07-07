import Foundation

/// Schedules incremental authorization retries using Swift tasks.
///
/// Sendability is delegated to `BackoffScheduler`, which guards pending task
/// ownership and retry counters behind its own locked state.
public final class AuthorizationRetryBackoff: @unchecked Sendable {
  private let scheduler: BackoffScheduler

  /// Builds one retry scheduler with incremental delays capped at the last value.
  public init(
    delays: [TimeInterval] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 60],
    logger: ProcessLogger,
    sleeper: any AsyncSleeper = TaskSleeper()
  ) {
    self.scheduler = BackoffScheduler(
      label: "authorization retry",
      delays: delays,
      logger: logger,
      logLevel: .debug,
      sleeper: sleeper
    )
  }

  /// Cancels any pending retry and resets the delay sequence.
  public func reset() {
    scheduler.cancel()
  }

  /// Schedules the next retry attempt when none is currently pending.
  public func schedule(_ action: @escaping @Sendable () -> Void) {
    scheduler.schedule {
      Task { @MainActor in
        action()
      }
    }
  }
}
