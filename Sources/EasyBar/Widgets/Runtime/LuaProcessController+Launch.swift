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
    process.terminationHandler = handleTermination
    return process
  }

  /// Handles Lua process termination and related cleanup logging.
  func handleTermination(process: Process) {
    logTerminationStatus(process.terminationStatus)

    if easyBarLuaProcessGroupPID == process.processIdentifier {
      easyBarLuaProcessGroupPID = 0
    }
  }

  /// Logs one Lua runtime termination status.
  func logTerminationStatus(_ status: Int32) {
    guard status != 0 else {
      easybarLog.info("lua runtime terminated status=\(status)")
      return
    }

    easybarLog.warn("lua runtime terminated status=\(status)")
  }
}
