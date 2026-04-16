import Darwin
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
      easybarLog.debug(
        "sending SIGTERM to lua process group pgid=\(processGroupIdentifier) pid=\(processIdentifier)"
      )
      kill(-processGroupIdentifier, SIGTERM)
    } else {
      easybarLog.debug("sending SIGTERM to lua process pid=\(processIdentifier)")
      kill(processIdentifier, SIGTERM)
    }

    let workItem = DispatchWorkItem {
      guard easyBarProcessIsRunning(processIdentifier) else { return }

      if let processGroupIdentifier, processGroupIdentifier > 0 {
        easybarLog.warn(
          "forcing lua process group shutdown pgid=\(processGroupIdentifier) pid=\(processIdentifier)"
        )
        kill(-processGroupIdentifier, SIGKILL)
      } else {
        easybarLog.warn("forcing lua process shutdown pid=\(processIdentifier)")
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
