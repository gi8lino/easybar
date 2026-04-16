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
/// When a dedicated process group is available, EasyBar signals the whole Lua
/// process group so any children created by the Lua runtime are cleaned up too.
/// Otherwise it falls back to the direct child process.
func easyBarTerminateLuaProcess(
  _ process: Process?,
  processGroupIdentifier: Int32?
) {
  guard let process else { return }
  guard process.isRunning else { return }

  easyBarLuaForcedKillWorkItem?.cancel()
  easyBarLuaForcedKillWorkItem = nil

  let processIdentifier = process.processIdentifier

  if let processGroupIdentifier, processGroupIdentifier > 0 {
    easybarLog.debug(
      "sending SIGTERM to lua process group pgid=\(processGroupIdentifier) pid=\(processIdentifier)"
    )
    kill(-processGroupIdentifier, SIGTERM)
  } else {
    easybarLog.debug("sending SIGTERM to lua process pid=\(processIdentifier)")
    process.terminate()
  }

  let workItem = DispatchWorkItem {
    guard process.isRunning else { return }

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
