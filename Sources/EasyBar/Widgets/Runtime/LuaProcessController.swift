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

  /// Returns the running Lua process identifier when available.
  var processIdentifier: Int32? {
    process?.processIdentifier
  }

  /// Starts the Lua runtime process and returns its pipes.
  func start() -> (process: Process, input: Pipe, output: Pipe, error: Pipe)? {
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

    easybarLog.debug("lua runtime started pid=\(process.processIdentifier)")

    return (process, pipes.input, pipes.output, pipes.error)
  }

  /// Stops the Lua runtime process.
  func shutdown() {
    guard let process else { return }

    easybarLog.debug("shutting down lua runtime pid=\(process.processIdentifier)")
    easyBarTerminateLuaProcess(process)
    self.process = nil
  }
}
