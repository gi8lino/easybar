import EasyBarShared
import Foundation

/// Actor-owned scripted widget runtime.
///
/// This actor owns the Lua handshake state, subscriptions, and tree updates.
actor WidgetEngine {
  private struct LuaCommandResponse: Encodable {
    let protocolVersion = WidgetTreeUpdate.supportedProtocolVersion
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
  private let configManager: ConfigManager
  private let luaRuntime: LuaRuntime
  private let eventHub: EventHub
  private let eventManager: EventManager
  private let widgetStore: WidgetStore
  private let metricsCoordinator: MetricsCoordinator
  private let commandRunner: LuaCommandRunner
  private let protocolDecoder = WidgetRuntimeProtocolDecoder()
  private let encoder = JSONEncoder()

  private var runtimeState = WidgetRuntimeState()
  private var scriptedRoots = Set<String>()
  private var started = false
  private var runtimeSessionID: UInt64 = 0
  private var activeAsyncCommandCount = 0

  /// Creates one widget engine.
  init(
    logger: ProcessLogger,
    luaRuntime: LuaRuntime,
    configManager: ConfigManager,
    eventHub: EventHub,
    eventManager: EventManager,
    widgetStore: WidgetStore,
    metricsCoordinator: MetricsCoordinator
  ) {
    self.logger = logger
    self.configManager = configManager
    self.luaRuntime = luaRuntime
    self.eventHub = eventHub
    self.eventManager = eventManager
    self.widgetStore = widgetStore
    self.metricsCoordinator = metricsCoordinator
    self.commandRunner = LuaCommandRunner(logger: logger.child("commands"))
  }

  /// Starts the scripted widget runtime.
  @discardableResult
  func start() async -> Bool {
    guard !started else {
      logger.debug("widget engine already started")
      return true
    }

    logger.debug("widget engine start begin")

    runtimeState.reset()
    activeAsyncCommandCount = 0

    await luaRuntime.setLineHandler { [weak self] line in
      Task {
        await self?.handleRuntimeTransportLine(line)
      }
    }

    let configSnapshot = await configManager.snapshot()

    guard await luaRuntime.start(config: configSnapshot) else {
      logger.warn("widget engine start failed because lua runtime did not launch")
      return false
    }

    runtimeSessionID &+= 1
    started = true

    logger.debug("widget engine start end")
    return true
  }

  /// Reloads the scripted widget runtime and clears rendered state.
  func reload() async {
    logger.debug("widget engine reload begin")

    let rootsToClear = scriptedRoots
    await shutdown()

    await MainActor.run {
      widgetStore.clear(roots: rootsToClear)
    }

    scriptedRoots.removeAll()
    let didRestart = await start()
    if !didRestart {
      logger.warn("widget engine reload completed without restarting lua runtime")
    }

    logger.debug("widget engine reload end")
  }

  /// Stops the scripted widget runtime and event sources.
  func shutdown() async {
    guard started else {
      logger.debug("widget engine shutdown skipped, not started")
      return
    }

    logger.debug("widget engine shutdown begin")

    started = false
    runtimeState.reset()
    activeAsyncCommandCount = 0

    await eventHub.clearLuaForwardedAppEvents()

    await MainActor.run {
      eventManager.stopLuaSubscriptions()
    }

    await luaRuntime.shutdown()

    logger.debug("widget engine shutdown end")
  }

  /// Handles one line of structured socket transport output from the Lua runtime.
  func handleRuntimeTransportLine(_ line: String) async {
    guard started else { return }

    logger.debug("lua transport: \(line)")

    do {
      let message = try protocolDecoder.decodeMessage(from: line)
      await handleRuntimeMessage(message)
    } catch WidgetRuntimeProtocolError.unsupportedProtocolVersion(let version) {
      metricsCoordinator.recordDecodeError()
      logger.warn(
        "unsupported lua protocol version",
        .field("expected", WidgetTreeUpdate.supportedProtocolVersion),
        .field("received", version.map(String.init(describing:)) ?? "nil")
      )
    } catch DecodingError.dataCorrupted {
      metricsCoordinator.recordDecodeError()
      logger.warn("invalid utf8: \(line)")
    } catch WidgetRuntimeProtocolError.invalidPayload(let message) {
      logger.warn(message)
    } catch {
      metricsCoordinator.recordDecodeError()
      logger.warn("json decode failed: \(line)")
      logger.debug("decode error: \(error)")
    }
  }

  /// Emits initial events after both subscriptions and readiness are known.
  private func emitInitialEventsIfPossible() async {
    guard runtimeState.canEmitInitialEvents else { return }

    runtimeState.didEmitInitialEvents = true
    logger.debug("emitting replayable widget events")

    await eventHub.emitReplayableState(for: runtimeState.requiredEvents)
    await eventHub.emit(.manualRefresh)
  }

  /// Handles one decoded runtime message.
  private func handleRuntimeMessage(_ message: WidgetRuntimeMessage) async {
    switch message {
    case .subscriptions(let requiredEvents):
      await handleSubscriptions(requiredEvents)
    case .ready:
      await handleReady()
    case .tree(let root, let nodes):
      await handleTree(root: root, nodes: nodes)
    case .clearRoot(let rootID):
      await handleClearRoot(rootID: rootID)
    case .commandRequest(let token, let command, let isSynchronous, let timeoutSeconds, let maxOutputBytes):
      await handleCommandRequest(
        token: token,
        command: command,
        isSynchronous: isSynchronous,
        timeoutSecondsOverride: timeoutSeconds,
        maxOutputBytesOverride: maxOutputBytes
      )
    }
  }

  /// Handles one subscription update from Lua.
  private func handleSubscriptions(_ requiredEvents: Set<String>) async {
    runtimeState.requiredEvents = requiredEvents
    runtimeState.hasSubscriptions = true

    metricsCoordinator.recordLuaSubscriptions(runtimeState.requiredEvents)
    logger.debug(
      "required events updated",
      .field("events", runtimeState.requiredEvents),
    )

    let requiredEvents = runtimeState.requiredEvents
    await eventHub.setLuaForwardedAppEvents(requiredEvents)

    await MainActor.run {
      eventManager.start(subscriptions: requiredEvents)
    }

    await emitInitialEventsIfPossible()
  }

  /// Handles the Lua runtime ready handshake.
  private func handleReady() async {
    logger.debug("lua runtime handshake received")

    runtimeState.isReady = true
    metricsCoordinator.recordLuaReady()

    await emitInitialEventsIfPossible()
  }

  /// Handles one rendered widget tree update.
  private func handleTree(root: String, nodes: [WidgetNodeState]) async {
    scriptedRoots.insert(root)

    logger.debug(
      "decoded widget tree",
      .field("root", root),
      .field("nodes", nodes.count)
    )
    metricsCoordinator.recordTreeUpdate(root: root, nodeCount: nodes.count)

    await MainActor.run {
      widgetStore.apply(root: root, nodes: nodes)
    }
  }

  /// Handles one explicit root-clear update from Lua.
  private func handleClearRoot(rootID: String) async {
    scriptedRoots.remove(rootID)
    logger.debug("decoded widget root clear", .field("root", rootID))

    await MainActor.run {
      widgetStore.clear(roots: [rootID])
    }
  }

  /// Handles one Lua command execution request.
  private func handleCommandRequest(
    token: String,
    command: String,
    isSynchronous: Bool,
    timeoutSecondsOverride: TimeInterval?,
    maxOutputBytesOverride: Int?
  ) async {
    let commandSettings = await configManager.luaCommandSettings()
    let commandLimits =
      LuaCommandRunner.Limits(
        timeoutSeconds: timeoutSecondsOverride ?? commandSettings.timeoutSeconds,
        maxOutputBytes: maxOutputBytesOverride ?? commandSettings.maxOutputBytes
      )

    logger.debug(
      "lua command requested",
      .field("token", token),
      .field("sync", isSynchronous),
      .field("command", command),
      .field("timeout_seconds", commandLimits.timeoutSeconds),
      .field("max_output_bytes", commandLimits.maxOutputBytes)
    )

    if isSynchronous {
      let result = await commandRunner.run(command: command, limits: commandLimits)
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
        .field("command", command)
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
    let runtimeSessionID = self.runtimeSessionID

    Task { [weak self] in
      let result = await commandRunner.run(command: command, limits: commandLimits)
      await self?.sendAsyncCommandResponse(
        token: token,
        result: result,
        runtimeSessionID: runtimeSessionID
      )
    }
  }

  /// Sends one command response back into the Lua runtime.
  private func sendCommandResponse(token: String, result: LuaCommandResult) async {
    let response = LuaCommandResponse(
      token: token,
      output: result.output,
      status: result.status
    )

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
    runtimeSessionID: UInt64
  ) async {
    activeAsyncCommandCount = max(0, activeAsyncCommandCount - 1)

    guard started, self.runtimeSessionID == runtimeSessionID else {
      logger.info(
        "dropping stale async lua command response",
        .field("token", token),
        .field("runtime_session_id", runtimeSessionID),
        .field("current_runtime_session_id", self.runtimeSessionID)
      )
      return
    }

    await sendCommandResponse(token: token, result: result)
  }
}
