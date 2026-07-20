import EasyBarShared
import Foundation

/// Handles Lua command requests, async command limits, and command responses.
actor LuaCommandService {
  private struct ActiveAsyncCommand {
    let runtimeSessionID: UInt64
    let task: Task<Void, Never>
  }

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

  private var activeAsyncCommandSessionID: UInt64?
  private var activeAsyncCommands: [String: ActiveAsyncCommand] = [:]

  init(logger: ProcessLogger, luaRuntime: LuaRuntime, configManager: ConfigManager) {
    self.logger = logger
    self.luaRuntime = luaRuntime
    self.configManager = configManager
    self.commandRunner = LuaCommandRunner(logger: logger)
  }

  /// Resets async command accounting during runtime start or shutdown.
  func resetActiveAsyncCommandCount() {
    cancelActiveAsyncCommands()
    activeAsyncCommandSessionID = nil
  }

  /// Handles one Lua command execution request.
  func handleCommandRequest(
    token: String,
    invocation: LuaCommandInvocation,
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
      .field("command_bytes", invocation.payloadByteCount),
      .field("timeout_seconds", commandLimits.timeoutSeconds),
      .field("max_output_bytes", commandLimits.maxOutputBytes)
    )

    if isSynchronous {
      let result = await commandRunner.run(
        invocation: invocation,
        limits: commandLimits,
        environment: commandSettings.environment
      )

      guard await isRuntimeSessionActive(runtimeSessionID) else {
        logger.debug(
          "dropping stale sync lua command response",
          .field("token", token),
          .field("runtime_session_id", runtimeSessionID)
        )
        return
      }

      await sendCommandResponse(token: token, result: result)
      return
    }

    if activeAsyncCommandSessionID != runtimeSessionID {
      cancelActiveAsyncCommands()
      activeAsyncCommandSessionID = runtimeSessionID
    }

    let maxAsyncJobs = commandSettings.maxAsyncJobs
    guard activeAsyncCommands.count < maxAsyncJobs else {
      logger.warn(
        "lua async command rejected because limit was reached",
        .field("token", token),
        .field("active_async_jobs", activeAsyncCommands.count),
        .field("max_async_jobs", maxAsyncJobs),
        .field("command_bytes", invocation.payloadByteCount)
      )
      await sendCommandResponse(
        token: token,
        result: LuaCommandResult(
          output: "\(invocation.asynchronousAPIName) rejected: max async job limit reached",
          status: 69
        )
      )
      return
    }

    let commandRunner = commandRunner

    let task = Task { [weak self] in
      let result = await commandRunner.run(
        invocation: invocation,
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

    activeAsyncCommands[token] = ActiveAsyncCommand(
      runtimeSessionID: runtimeSessionID,
      task: task
    )
  }

  /// Cancels one host-owned asynchronous command from the active Lua runtime session.
  func cancelAsyncCommand(token: String, runtimeSessionID: UInt64) {
    guard activeAsyncCommandSessionID == runtimeSessionID else { return }
    guard let command = activeAsyncCommands[token], command.runtimeSessionID == runtimeSessionID
    else {
      logger.debug("lua async cancellation ignored for unknown token", .field("token", token))
      return
    }

    logger.debug("cancelling lua async command", .field("token", token))
    command.task.cancel()
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
    guard activeAsyncCommandSessionID == runtimeSessionID,
      let command = activeAsyncCommands[token],
      command.runtimeSessionID == runtimeSessionID
    else {
      logger.debug(
        "dropping async lua command response from stale session accounting",
        .field("token", token),
        .field("runtime_session_id", runtimeSessionID)
      )
      return
    }
    activeAsyncCommands.removeValue(forKey: token)

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

  /// Cancels and forgets all async command tasks owned by the current session.
  private func cancelActiveAsyncCommands() {
    let tasks = activeAsyncCommands.values.map(\.task)
    activeAsyncCommands.removeAll()

    for task in tasks {
      task.cancel()
    }
  }
}
