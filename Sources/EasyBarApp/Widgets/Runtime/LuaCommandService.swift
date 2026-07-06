import EasyBarShared
import Foundation

/// Handles Lua command requests, async command limits, and command responses.
actor LuaCommandService {
  private struct LuaCommandResponse: Encodable {
    let protocolVersion = easyBarLuaRuntimeProtocolVersion
    let type = "command_response"
    let token: String
    let output: String
    let status: Int32

    enum CodingKeys: String, CodingKey {
      case protocolVersion = "protocol_version"
      case type
      case token
      case output
      case status
    }
  }

  private let logger: ProcessLogger
  private let luaRuntime: LuaRuntime
  private let configManager: ConfigManager
  private let commandRunner: LuaCommandRunner
  private let encoder = JSONEncoder()

  private var activeAsyncCommandCount = 0

  init(logger: ProcessLogger, luaRuntime: LuaRuntime, configManager: ConfigManager) {
    self.logger = logger
    self.luaRuntime = luaRuntime
    self.configManager = configManager
    self.commandRunner = LuaCommandRunner(logger: logger)
  }

  /// Resets async command accounting during runtime start or shutdown.
  func resetActiveAsyncCommandCount() {
    activeAsyncCommandCount = 0
  }

  /// Handles one Lua command execution request.
  func handleCommandRequest(
    token: String,
    command: String,
    isSynchronous: Bool,
    timeoutSecondsOverride: TimeInterval?,
    maxOutputBytesOverride: Int?,
    runtimeSessionID: UInt64,
    isRuntimeSessionActive: @escaping @Sendable (UInt64) async -> Bool
  ) async {
    let commandSettings = await configManager.luaCommandSettings()
    let commandLimits = LuaCommandRunner.Limits(
      timeoutSeconds: timeoutSecondsOverride ?? commandSettings.timeoutSeconds,
      maxOutputBytes: maxOutputBytesOverride ?? commandSettings.maxOutputBytes
    )

    logger.debug(
      "lua command requested",
      .field("token", token),
      .field("sync", isSynchronous),
      .field("command_bytes", command.utf8.count),
      .field("timeout_seconds", commandLimits.timeoutSeconds),
      .field("max_output_bytes", commandLimits.maxOutputBytes)
    )

    if isSynchronous {
      let result = await commandRunner.run(
        command: command,
        limits: commandLimits,
        environment: commandSettings.environment
      )
      await sendCommandResponse(token: token, result: result)
      return
    }

    let maxAsyncJobs = commandSettings.maxAsyncJobs
    guard activeAsyncCommandCount < maxAsyncJobs else {
      logger.warn(
        "lua async command rejected because limit was reached",
        .field("token", token),
        .field("active_async_jobs", activeAsyncCommandCount),
        .field("max_async_jobs", maxAsyncJobs),
        .field("command_bytes", command.utf8.count)
      )
      await sendCommandResponse(
        token: token,
        result: LuaCommandResult(
          output: "easybar.exec_async rejected: max async job limit reached",
          status: 69
        )
      )
      return
    }

    activeAsyncCommandCount += 1
    let commandRunner = commandRunner

    Task { [weak self] in
      let result = await commandRunner.run(
        command: command,
        limits: commandLimits,
        environment: commandSettings.environment
      )
      await self?.sendAsyncCommandResponse(
        token: token,
        result: result,
        runtimeSessionID: runtimeSessionID,
        isRuntimeSessionActive: isRuntimeSessionActive
      )
    }
  }

  /// Sends one command response back into the Lua runtime.
  private func sendCommandResponse(token: String, result: LuaCommandResult) async {
    let response = LuaCommandResponse(token: token, output: result.output, status: result.status)

    guard
      let data = try? encoder.encode(response),
      let encoded = String(data: data, encoding: .utf8)
    else {
      logger.error("failed to encode lua command response", .field("token", token))
      return
    }

    await luaRuntime.send(encoded)
  }

  /// Sends one async command response only when the originating runtime session is still active.
  private func sendAsyncCommandResponse(
    token: String,
    result: LuaCommandResult,
    runtimeSessionID: UInt64,
    isRuntimeSessionActive: @escaping @Sendable (UInt64) async -> Bool
  ) async {
    activeAsyncCommandCount = max(0, activeAsyncCommandCount - 1)

    guard await isRuntimeSessionActive(runtimeSessionID) else {
      logger.debug(
        "dropping stale async lua command response",
        .field("token", token),
        .field("runtime_session_id", runtimeSessionID)
      )
      return
    }

    await sendCommandResponse(token: token, result: result)
  }
}
