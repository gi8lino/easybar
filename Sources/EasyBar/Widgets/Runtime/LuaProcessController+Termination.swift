import Darwin
import Foundation

/// Tracks the pending forced-kill work item for the active Lua process.
var easyBarLuaForcedKillWorkItem: DispatchWorkItem?

/// Queue used for deferred forced termination of the Lua process.
private let easyBarLuaTerminationQueue = DispatchQueue(
  label: "easybar.lua.termination",
  qos: .utility
)

/// Grace period between terminate and forced kill.
private let easyBarLuaTerminationGracePeriod: DispatchTimeInterval = .milliseconds(150)

/// Terminates the Lua runtime process.
///
/// EasyBar signals the whole Lua process group so any children created by the
/// Lua runtime are cleaned up too. If the process group identifier is missing,
/// it falls back to the direct child process identifier.
func easyBarTerminateLuaProcess(
  processIdentifier: Int32?,
  processGroupIdentifier: Int32?
) {
  guard let processIdentifier else { return }
  guard easyBarProcessIsRunning(processIdentifier) else { return }

  easyBarLuaForcedKillWorkItem?.cancel()
  easyBarLuaForcedKillWorkItem = nil

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

  easyBarLuaForcedKillWorkItem = workItem
  easyBarLuaTerminationQueue.asyncAfter(
    deadline: .now() + easyBarLuaTerminationGracePeriod,
    execute: workItem
  )
}

/// Returns whether the given process identifier still exists.
private func easyBarProcessIsRunning(_ processIdentifier: Int32) -> Bool {
  if kill(processIdentifier, 0) == 0 {
    return true
  }

  return errno == EPERM
}
