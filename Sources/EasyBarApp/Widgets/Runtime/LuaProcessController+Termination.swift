import Darwin
import EasyBarShared
import Foundation

/// Grace period between terminate and forced kill.
private let easyBarLuaTerminationGracePeriodNanoseconds: UInt64 = 150_000_000

extension LuaProcessController {
  /// Terminates the Lua runtime process tree and schedules one forced kill fallback.
  func terminateProcess(processIdentifier: Int32, processGroupIdentifier: Int32?) {
    guard easyBarProcessIsRunning(processIdentifier) else { return }

    cancelForcedKillWorkItem()

    if let processGroupIdentifier, processGroupIdentifier > 0 {
      logger.debug(
        "sending SIGTERM to lua process group",
        .field("pgid", processGroupIdentifier),
        .field("pid", processIdentifier)
      )
      kill(-processGroupIdentifier, SIGTERM)
    } else {
      logger.debug(
        "sending SIGTERM to lua process",
        .field("pid", processIdentifier),
      )
      kill(processIdentifier, SIGTERM)
    }

    let task = Task.detached(priority: .utility) { [weak self] in
      do {
        try await Task.sleep(nanoseconds: easyBarLuaTerminationGracePeriodNanoseconds)
      } catch {
        return
      }

      guard let self else { return }
      guard easyBarProcessIsRunning(processIdentifier) else { return }

      if let processGroupIdentifier, processGroupIdentifier > 0 {
        self.logger.warn(
          "forcing lua process group shutdown",
          .field("pgid", processGroupIdentifier),
          .field("pid", processIdentifier)
        )
        kill(-processGroupIdentifier, SIGKILL)
      } else {
        self.logger.warn("forcing lua process shutdown", .field("pid", processIdentifier))
        kill(processIdentifier, SIGKILL)
      }
    }

    withLock {
      forcedKillTask = task
    }
  }

  /// Cancels the pending forced kill work item when present.
  func cancelForcedKillWorkItem() {
    let task = withLock { () -> Task<Void, Never>? in
      let task = forcedKillTask
      forcedKillTask = nil
      return task
    }

    task?.cancel()
  }
}

/// Returns whether the given process identifier still exists.
private func easyBarProcessIsRunning(_ processIdentifier: Int32) -> Bool {
  if kill(processIdentifier, 0) == 0 {
    return true
  }

  return errno == EPERM
}
