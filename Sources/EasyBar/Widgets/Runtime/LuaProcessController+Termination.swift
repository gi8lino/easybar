import Darwin
import EasyBarShared
import Foundation

/// Queue used for deferred forced termination of the Lua process.
private let easyBarLuaTerminationQueue = DispatchQueue(
  label: "easybar.lua.termination",
  qos: .utility
)

/// Grace period between terminate and forced kill.
private let easyBarLuaTerminationGracePeriod: DispatchTimeInterval = .milliseconds(150)

extension LuaProcessController {
  /// Terminates the Lua runtime process tree and schedules one forced kill fallback.
  func terminateProcess(processIdentifier: Int32, processGroupIdentifier: Int32?) {
    guard easyBarProcessIsRunning(processIdentifier) else { return }

    cancelForcedKillWorkItem()

    if let processGroupIdentifier, processGroupIdentifier > 0 {
      logger.debug(
        "sending SIGTERM to lua process group",
        logField("pgid", processGroupIdentifier),
        logField("pid", processIdentifier)
      )
      kill(-processGroupIdentifier, SIGTERM)
    } else {
      logger.debug("sending SIGTERM to lua process", logField("pid", processIdentifier))
      kill(processIdentifier, SIGTERM)
    }

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      guard easyBarProcessIsRunning(processIdentifier) else { return }

      if let processGroupIdentifier, processGroupIdentifier > 0 {
        self.logger.warn(
          "forcing lua process group shutdown",
          logField("pgid", processGroupIdentifier),
          logField("pid", processIdentifier)
        )
        kill(-processGroupIdentifier, SIGKILL)
      } else {
        self.logger.warn("forcing lua process shutdown", logField("pid", processIdentifier))
        kill(processIdentifier, SIGKILL)
      }
    }

    withLock {
      forcedKillWorkItem = workItem
    }

    easyBarLuaTerminationQueue.asyncAfter(
      deadline: .now() + easyBarLuaTerminationGracePeriod,
      execute: workItem
    )
  }

  /// Cancels the pending forced kill work item when present.
  func cancelForcedKillWorkItem() {
    let workItem = withLock { () -> DispatchWorkItem? in
      let workItem = forcedKillWorkItem
      forcedKillWorkItem = nil
      return workItem
    }

    workItem?.cancel()
  }
}

/// Returns whether the given process identifier still exists.
private func easyBarProcessIsRunning(_ processIdentifier: Int32) -> Bool {
  if kill(processIdentifier, 0) == 0 {
    return true
  }

  return errno == EPERM
}
