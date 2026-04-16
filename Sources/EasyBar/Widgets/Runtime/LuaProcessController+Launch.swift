import Darwin
import Foundation

extension LuaProcessController {

  /// Resolves the launch inputs for one Lua runtime process.
  func launchContext() -> LaunchContext? {
    guard let runtimePath = resolvedRuntimePath() else { return nil }

    return LaunchContext(
      runtimePath: runtimePath,
      luaPath: Config.shared.luaPath,
      widgetsPath: Config.shared.widgetsPath
    )
  }

  /// Resolves the bundled Lua runtime script path.
  func resolvedRuntimePath() -> String? {
    guard let runtime = Bundle.module.url(forResource: "runtime", withExtension: "lua") else {
      easybarLog.error("runtime.lua not found")
      return nil
    }

    return runtime.path
  }

  /// Logs one Lua runtime launch request.
  func logLaunch(context: LaunchContext) {
    easybarLog.debug("starting lua runtime")
    easybarLog.debug("lua binary: \(context.luaPath)")
    easybarLog.debug("lua script: \(context.runtimePath)")
    easybarLog.debug("widgets path: \(context.widgetsPath)")
  }

  /// Builds one configured Lua runtime process.
  func makeProcess(context: LaunchContext, pipes: LaunchPipes) -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: context.luaPath)
    process.arguments = [context.runtimePath, context.widgetsPath]
    process.standardInput = pipes.input
    process.standardOutput = pipes.output
    process.standardError = pipes.error
    process.terminationHandler = { [weak self] process in
      self?.handleTermination(process: process)
    }
    return process
  }

  /// Moves the Lua runtime into its own process group when possible.
  ///
  /// This isolates the runtime subtree from the app process for signal handling.
  /// If the handoff fails, the caller falls back to direct PID-based termination.
  func assignDedicatedProcessGroup(to process: Process) -> Int32? {
    let pid = process.processIdentifier
    guard pid > 0 else {
      easybarLog.warn("lua runtime process group assignment skipped because pid is invalid")
      return nil
    }

    if setpgid(pid, pid) == 0 {
      return pid
    }

    let code = errno
    easybarLog.warn(
      "failed to move lua runtime into its own process group pid=\(pid) errno=\(code)"
    )

    return nil
  }

  /// Handles Lua process termination and related cleanup logging.
  func handleTermination(process: Process) {
    easyBarLuaForcedKillWorkItem?.cancel()
    easyBarLuaForcedKillWorkItem = nil

    let pid = process.processIdentifier
    let status = process.terminationStatus

    clearTrackedProcessIfMatching(pid: pid)
    logTerminationStatus(status, processIdentifier: pid)
  }

  /// Logs one Lua runtime termination status.
  func logTerminationStatus(_ status: Int32, processIdentifier: Int32) {
    guard status != 0 else {
      easybarLog.info("lua runtime terminated pid=\(processIdentifier) status=\(status)")
      return
    }

    easybarLog.warn("lua runtime terminated pid=\(processIdentifier) status=\(status)")
  }
}
