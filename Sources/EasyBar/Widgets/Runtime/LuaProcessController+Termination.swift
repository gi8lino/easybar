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
/// A soft terminate is attempted first, then a forced kill shortly after on a
/// background queue. This prevents a stuck Lua child from surviving shutdown
/// without blocking the calling thread.
func easyBarTerminateLuaProcess(_ process: Process?) {
  guard let process else { return }
  guard process.isRunning else { return }

  easyBarLuaForcedKillWorkItem?.cancel()
  easyBarLuaForcedKillWorkItem = nil

  process.terminate()

  let processIdentifier = process.processIdentifier
  let workItem = DispatchWorkItem {
    guard process.isRunning else { return }
    kill(processIdentifier, SIGKILL)
  }

  easyBarLuaForcedKillWorkItem = workItem
  easyBarLuaTerminationQueue.asyncAfter(
    deadline: .now() + easyBarLuaTerminationGracePeriod,
    execute: workItem
  )
}
