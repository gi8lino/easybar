import EasyBarShared
import Foundation

/// Owns delayed AeroSpace refresh work scheduled after app launches.
final class AeroSpaceLaunchRefreshScheduler: @unchecked Sendable {
  private struct State {
    var pendingTask: Task<Void, Never>?
    var pendingTaskID: UInt64?
    var nextTaskID: UInt64 = 1
  }

  private let delayNanoseconds: UInt64
  private let logger: ProcessLogger
  private let state = LockedState(State())

  /// Creates a launch refresh scheduler.
  init(
    delayNanoseconds: UInt64 = 600_000_000,
    logger: ProcessLogger
  ) {
    self.delayNanoseconds = delayNanoseconds
    self.logger = logger
  }

  /// Schedules one delayed refresh and cancels any older pending launch refresh.
  func schedule(
    appName: String,
    generation: UInt64,
    shouldExecute: @escaping @Sendable (UInt64) -> Bool,
    refresh: @escaping @Sendable () -> Void
  ) {
    cancel(reason: "new app launch")

    let scheduled = state.withLock { state -> (id: UInt64, generation: UInt64) in
      let id = state.nextTaskID
      state.nextTaskID &+= 1
      state.pendingTaskID = id
      return (id, generation)
    }

    let refreshTask = Task { [weak self] in
      guard let self else { return }

      do {
        try await Task.sleep(nanoseconds: self.delayNanoseconds)
      } catch {
        return
      }

      guard shouldExecute(scheduled.generation) else { return }
      guard self.clearPendingTask(id: scheduled.id) else { return }

      self.logger.debug(
        "aerospace delayed launch refresh firing",
        .field("app", appName)
      )
      refresh()
    }

    let shouldCancel = state.withLock { state -> Bool in
      guard state.pendingTaskID == scheduled.id else { return true }
      state.pendingTask = refreshTask
      return false
    }

    if shouldCancel {
      refreshTask.cancel()
    }
  }

  /// Cancels any delayed launch refresh once a stronger signal arrives first.
  func cancel(reason: String) {
    let task = state.withLock { state -> Task<Void, Never>? in
      let task = state.pendingTask
      state.pendingTask = nil
      state.pendingTaskID = nil
      return task
    }

    guard let task else { return }
    task.cancel()
    logger.debug(
      "aerospace delayed launch refresh canceled",
      .field("reason", reason)
    )
  }

  /// Clears the pending launch refresh if it still matches the fired work item.
  private func clearPendingTask(id: UInt64) -> Bool {
    state.withLock { state -> Bool in
      guard state.pendingTaskID == id else { return false }
      state.pendingTask = nil
      state.pendingTaskID = nil
      return true
    }
  }
}
