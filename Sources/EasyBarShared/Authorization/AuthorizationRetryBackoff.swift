import Foundation

/// Schedules incremental authorization retries on one dispatch queue.
public final class AuthorizationRetryBackoff {
  private let delays: [TimeInterval]
  private let queue: DispatchQueue
  private let debugLog: (String) -> Void

  private var scheduledWorkItem: DispatchWorkItem?
  private var attemptIndex = 0

  /// Builds one retry scheduler with incremental delays capped at the last value.
  public init(
    delays: [TimeInterval] = [1, 2, 3, 5, 8, 13, 21, 34, 55, 60],
    queue: DispatchQueue = .main,
    debugLog: @escaping (String) -> Void = { _ in }
  ) {
    self.delays = delays
    self.queue = queue
    self.debugLog = debugLog
  }

  /// Cancels any pending retry and resets the delay sequence.
  public func reset() {
    scheduledWorkItem?.cancel()
    scheduledWorkItem = nil
    attemptIndex = 0
  }

  /// Schedules the next retry attempt when none is currently pending.
  public func schedule(_ action: @escaping () -> Void) {
    guard scheduledWorkItem == nil else { return }

    let delay = delays[min(attemptIndex, delays.count - 1)]
    attemptIndex += 1

    let workItem = DispatchWorkItem { [weak self] in
      self?.scheduledWorkItem = nil
      action()
    }

    scheduledWorkItem = workItem
    debugLog(
      """
      authorization retry scheduled
      delay=\(delay)
      """)
    queue.asyncAfter(deadline: .now() + delay, execute: workItem)
  }
}
