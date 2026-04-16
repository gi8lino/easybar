import Foundation

/// Owns Lua process lifecycle.
final class LuaProcessController {

  struct LaunchContext {
    let runtimePath: String
    let luaPath: String
    let widgetsPath: String
  }

  struct LaunchPipes {
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
  }

  fileprivate(set) var process: Process?
  fileprivate(set) var processGroupIdentifier: Int32?
  fileprivate(set) var isShuttingDown = false

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    process?.processIdentifier
  }

  /// Starts the Lua runtime process and returns its pipes.
  func start() -> (process: Process, input: Pipe, output: Pipe, error: Pipe)? {
    if isShuttingDown {
      easybarLog.debug("lua runtime start skipped because shutdown is in progress")
      return nil
    }

    guard process == nil else {
      easybarLog.debug("lua runtime already started")
      return nil
    }

    guard let context = launchContext() else { return nil }

    logLaunch(context: context)

    let pipes = LaunchPipes()
    let process = makeProcess(context: context, pipes: pipes)

    do {
      try process.run()
    } catch {
      easybarLog.error("failed to start lua runtime: \(error)")
      return nil
    }

    easyBarLuaForcedKillWorkItem?.cancel()
    easyBarLuaForcedKillWorkItem = nil

    self.process = process
    processGroupIdentifier = assignDedicatedProcessGroup(to: process)
    isShuttingDown = false

    if let processGroupIdentifier {
      easybarLog.debug(
        "lua runtime started pid=\(process.processIdentifier) pgid=\(processGroupIdentifier)"
      )
    } else {
      easybarLog.debug("lua runtime started pid=\(process.processIdentifier) pgid=<unavailable>")
    }

    return (process, pipes.input, pipes.output, pipes.error)
  }

  /// Stops the Lua runtime process.
  func shutdown() {
    guard let process else {
      easybarLog.debug("lua runtime shutdown skipped because no process is running")
      return
    }

    guard !isShuttingDown else {
      easybarLog.debug("lua runtime shutdown already in progress pid=\(process.processIdentifier)")
      return
    }

    isShuttingDown = true

    if let processGroupIdentifier {
      easybarLog.debug(
        "shutting down lua runtime pid=\(process.processIdentifier) pgid=\(processGroupIdentifier)"
      )
    } else {
      easybarLog.debug("shutting down lua runtime pid=\(process.processIdentifier)")
    }

    easyBarTerminateLuaProcess(
      process,
      processGroupIdentifier: processGroupIdentifier
    )
  }

  /// Clears the currently tracked Lua process state.
  func clearTrackedProcessState() {
    process = nil
    processGroupIdentifier = nil
    isShuttingDown = false
  }

  /// Clears the tracked Lua process only when it matches the given pid.
  func clearTrackedProcessIfMatching(pid: Int32) {
    guard process?.processIdentifier == pid else { return }
    clearTrackedProcessState()
  }
}
