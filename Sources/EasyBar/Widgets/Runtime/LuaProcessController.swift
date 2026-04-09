import Foundation

/// Tracks the process group ID of the running Lua runtime process.
/// This lets EasyBar terminate the runtime and any child processes it spawned.
var easyBarLuaProcessGroupPID: pid_t = 0

/// Terminates the Lua runtime process group.
///
/// A soft terminate is attempted first, then a forced kill shortly after.
/// This prevents orphaned child processes from surviving reload/shutdown.
private func easyBarTerminateLuaProcessGroup() {
  let pid = easyBarLuaProcessGroupPID
  guard pid > 0 else { return }

  kill(-pid, SIGTERM)
  usleep(150_000)
  kill(-pid, SIGKILL)

  easyBarLuaProcessGroupPID = 0
}

/// Handles termination-related signals by shutting down the Lua process group first.
private func easyBarSignalHandler(_ signal: Int32) {
  easyBarTerminateLuaProcessGroup()
  Darwin.signal(signal, SIG_DFL)
  Darwin.raise(signal)
}

/// Owns Lua process lifecycle and process-group shutdown behavior.
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

  private(set) var process: Process?
  private var signalHandlersInstalled = false

  /// Starts the Lua runtime process and returns its pipes.
  func start() -> (process: Process, input: Pipe, output: Pipe, error: Pipe)? {
    guard process == nil else {
      easybarLog.debug("lua runtime already started")
      return nil
    }

    installSignalHandlersIfNeeded()

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

    let pid = process.processIdentifier

    // Put Lua into its own process group so shutdown can kill the whole tree.
    _ = setpgid(pid, pid)
    easyBarLuaProcessGroupPID = pid

    self.process = process

    easybarLog.debug("lua runtime started pid=\(pid)")

    return (process, pipes.input, pipes.output, pipes.error)
  }

  /// Stops the Lua runtime process.
  func shutdown() {
    guard let process else { return }

    easybarLog.debug("shutting down lua runtime pid=\(process.processIdentifier)")
    easyBarTerminateLuaProcessGroup()
    self.process = nil
  }

  /// Installs signal handlers once for clean Lua shutdown on exit/crash.
  private func installSignalHandlersIfNeeded() {
    guard !signalHandlersInstalled else { return }
    signalHandlersInstalled = true

    Darwin.signal(SIGINT, easyBarSignalHandler)
    Darwin.signal(SIGTERM, easyBarSignalHandler)
    Darwin.signal(SIGHUP, easyBarSignalHandler)
    Darwin.signal(SIGABRT, easyBarSignalHandler)
    Darwin.signal(SIGQUIT, easyBarSignalHandler)
  }
}
