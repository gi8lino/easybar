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
  private let luaRuntime: LuaRuntime
  private let commandRunner: LuaCommandRunner
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  private var runtimeState = WidgetRuntimeState()
  private var scriptedRoots = Set<String>()
  private var started = false
  private var runtimeSessionID: UInt64 = 0

  /// Creates one widget engine.
  init(
    logger: ProcessLogger,
    luaRuntime: LuaRuntime
  ) {
    self.logger = logger
    self.luaRuntime = luaRuntime
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

    await luaRuntime.setLineHandler { [weak self] line in
      Task {
        await self?.handleRuntimeTransportLine(line)
      }
    }

    guard await luaRuntime.start() else {
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
      WidgetStore.shared.clear(roots: rootsToClear)
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

    await EventHub.shared.clearLuaForwardedAppEvents()

    await MainActor.run {
      EventManager.shared.stopLuaSubscriptions()
    }

    await luaRuntime.shutdown()

    logger.debug("widget engine shutdown end")
  }

  /// Handles one line of structured socket transport output from the Lua runtime.
  func handleRuntimeTransportLine(_ line: String) async {
    guard started else { return }

    logger.debug("lua transport: \(line)")

    do {
      let update = try decodeUpdate(from: line)
      guard update.isSupportedProtocolVersion else {
        MetricsCoordinator.shared.recordDecodeError()
        logger.warn(
          "unsupported lua protocol version",
          .field("expected", WidgetTreeUpdate.supportedProtocolVersion),
          .field("received", update.protocolVersion.map(String.init(describing:)) ?? "nil")
        )
        return
      }
      await handleUpdate(update, rawLine: line)
    } catch DecodingError.dataCorrupted {
      MetricsCoordinator.shared.recordDecodeError()
      logger.warn("invalid utf8: \(line)")
    } catch {
      MetricsCoordinator.shared.recordDecodeError()
      logger.warn("json decode failed: \(line)")
      logger.debug("decode error: \(error)")
    }
  }

  /// Decodes one structured runtime update line.
  private func decodeUpdate(from line: String) throws -> WidgetTreeUpdate {
    guard let data = line.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: [], debugDescription: "invalid utf8")
      )
    }

    return try decoder.decode(WidgetTreeUpdate.self, from: data)
  }

  /// Emits initial events after both subscriptions and readiness are known.
  private func emitInitialEventsIfPossible() async {
    guard runtimeState.canEmitInitialEvents else { return }

    runtimeState.didEmitInitialEvents = true
    logger.debug("emitting replayable widget events")

    await EventHub.shared.emitReplayableState(for: runtimeState.requiredEvents)
    await EventHub.shared.emit(.manualRefresh)
  }

  /// Handles one decoded Lua runtime update.
  private func handleUpdate(_ update: WidgetTreeUpdate, rawLine: String) async {
    guard !update.isSubscriptions else {
      await handleSubscriptions(update)
      return
    }

    guard !update.isReady else {
      await handleReady()
      return
    }

    guard !update.isClearRoot else {
      await handleClearRoot(update, rawLine: rawLine)
      return
    }

    guard !update.isCommandRequest else {
      await handleCommandRequest(update, rawLine: rawLine)
      return
    }

    guard update.isTree else {
      logger.warn("unknown lua message: \(rawLine)")
      return
    }

    await handleTree(update, rawLine: rawLine)
  }

  /// Handles one subscription update from Lua.
  private func handleSubscriptions(_ update: WidgetTreeUpdate) async {
    runtimeState.requiredEvents = Set(update.subscribedEvents)
    runtimeState.hasSubscriptions = true

    MetricsCoordinator.shared.recordLuaSubscriptions(runtimeState.requiredEvents)
    logger.debug(
      "required events updated",
      .field("events", runtimeState.requiredEvents),
    )

    let requiredEvents = runtimeState.requiredEvents
    await EventHub.shared.setLuaForwardedAppEvents(requiredEvents)

    await MainActor.run {
      EventManager.shared.start(subscriptions: requiredEvents)
    }

    await emitInitialEventsIfPossible()
  }

  /// Handles the Lua runtime ready handshake.
  private func handleReady() async {
    logger.debug("lua runtime handshake received")

    runtimeState.isReady = true
    MetricsCoordinator.shared.recordLuaReady()

    await emitInitialEventsIfPossible()
  }

  /// Handles one rendered widget tree update.
  private func handleTree(_ update: WidgetTreeUpdate, rawLine: String) async {
    guard let tree = update.treePayload else {
      logger.warn("unknown lua message: \(rawLine)")
      return
    }

    scriptedRoots.insert(tree.root)

    logger.debug(
      "decoded widget tree",
      .field("root", tree.root),
      .field("nodes", tree.nodes.count)
    )
    MetricsCoordinator.shared.recordTreeUpdate(root: tree.root, nodeCount: tree.nodes.count)

    await MainActor.run {
      WidgetStore.shared.apply(root: tree.root, nodes: tree.nodes)
    }
  }

  /// Handles one explicit root-clear update from Lua.
  private func handleClearRoot(_ update: WidgetTreeUpdate, rawLine: String) async {
    guard let rootID = update.clearRootID else {
      logger.warn("invalid lua clear-root update: \(rawLine)")
      return
    }

    scriptedRoots.remove(rootID)
    logger.debug("decoded widget root clear", .field("root", rootID))

    await MainActor.run {
      WidgetStore.shared.clear(roots: [rootID])
    }
  }

  /// Handles one Lua command execution request.
  private func handleCommandRequest(_ update: WidgetTreeUpdate, rawLine: String) async {
    guard let request = update.commandRequestPayload else {
      logger.warn("invalid lua command request: \(rawLine)")
      return
    }

    logger.debug(
      "lua command requested",
      .field("token", request.token),
      .field("sync", request.isSynchronous),
      .field("command", request.command)
    )

    if request.isSynchronous {
      let result = await commandRunner.run(command: request.command)
      await sendCommandResponse(token: request.token, result: result)
      return
    }

    let commandRunner = commandRunner
    let runtimeSessionID = self.runtimeSessionID

    Task { [weak self] in
      let result = await commandRunner.run(command: request.command)
      await self?.sendAsyncCommandResponse(
        token: request.token,
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
