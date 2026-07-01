import EasyBarShared
import Foundation

/// Actor-owned scripted widget runtime.
///
/// This actor owns the Lua handshake state, subscriptions, and tree updates.
actor WidgetEngine {
  private let logger: ProcessLogger
  private let configManager: ConfigManager
  private let luaRuntime: LuaRuntime
  private let eventHub: EventHub
  private let eventManager: EventManager
  private let widgetStore: WidgetStore
  private let metricsCoordinator: MetricsCoordinator
  private let commandService: LuaCommandService
  private let protocolDecoder = WidgetRuntimeProtocolDecoder()

  private var runtimeState = WidgetRuntimeState()
  private var scriptedRoots = Set<String>()
  private var started = false
  private var runtimeSessionID: UInt64 = 0

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
    self.commandService = LuaCommandService(
      logger: logger.child("commands"),
      luaRuntime: luaRuntime,
      configManager: configManager
    )
  }

  @discardableResult
  func start() async -> Bool {
    guard !started else {
      logger.debug("widget engine already started")
      return true
    }

    logger.debug("widget engine start begin")

    runtimeState.reset()
    await commandService.resetActiveAsyncCommandCount()

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

  func shutdown() async {
    guard started else {
      logger.debug("widget engine shutdown skipped, not started")
      return
    }

    logger.debug("widget engine shutdown begin")

    started = false
    runtimeState.reset()
    await commandService.resetActiveAsyncCommandCount()

    await eventHub.clearLuaForwardedAppEvents()

    await MainActor.run {
      eventManager.stopLuaSubscriptions()
    }

    await luaRuntime.shutdown()

    logger.debug("widget engine shutdown end")
  }

  func handleRuntimeTransportLine(_ line: String) async {
    guard started else { return }

    logger.trace("lua transport line received", .field("bytes", line.utf8.count))

    do {
      let message = try protocolDecoder.decodeMessage(from: line)
      await handleRuntimeMessage(message)
    } catch WidgetRuntimeProtocolError.unsupportedProtocolVersion(let version) {
      await metricsCoordinator.recordDecodeError()
      logger.warn(
        "unsupported lua protocol version",
        .field("expected", WidgetTreeUpdate.supportedProtocolVersion),
        .field("received", version.map(String.init(describing:)) ?? "nil")
      )
    } catch DecodingError.dataCorrupted {
      await metricsCoordinator.recordDecodeError()
      logger.warn("invalid lua transport utf8", .field("bytes", line.utf8.count))
    } catch WidgetRuntimeProtocolError.invalidPayload(let message) {
      logger.warn(message)
    } catch {
      await metricsCoordinator.recordDecodeError()
      logger.warn("lua transport json decode failed", .field("bytes", line.utf8.count))
      logger.debug("decode error: \(error)")
    }
  }

  private func emitInitialEventsIfPossible() async {
    guard runtimeState.canEmitInitialEvents else { return }

    runtimeState.didEmitInitialEvents = true
    logger.debug("emitting replayable widget events")

    await eventHub.emitReplayableState(for: runtimeState.requiredEvents)
    await eventHub.emit(.manualRefresh)
  }

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
      await commandService.handleCommandRequest(
        token: token,
        command: command,
        isSynchronous: isSynchronous,
        timeoutSecondsOverride: timeoutSeconds,
        maxOutputBytesOverride: maxOutputBytes,
        runtimeSessionID: runtimeSessionID,
        isRuntimeSessionActive: { [weak self] sessionID in
          guard let self else { return false }
          return await self.isRuntimeSessionActive(sessionID)
        }
      )
    }
  }

  private func isRuntimeSessionActive(_ sessionID: UInt64) -> Bool {
    started && runtimeSessionID == sessionID
  }

  private func handleSubscriptions(_ requiredEvents: Set<String>) async {
    runtimeState.requiredEvents = requiredEvents
    runtimeState.hasSubscriptions = true

    await metricsCoordinator.recordLuaSubscriptions(runtimeState.requiredEvents)
    logger.debug("required events updated", .field("events", runtimeState.requiredEvents))

    let requiredEvents = runtimeState.requiredEvents
    await eventHub.setLuaForwardedAppEvents(requiredEvents)

    await MainActor.run {
      eventManager.start(subscriptions: requiredEvents)
    }

    await emitInitialEventsIfPossible()
  }

  private func handleReady() async {
    logger.debug("lua runtime handshake received")

    runtimeState.isReady = true
    await metricsCoordinator.recordLuaReady()

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
    await metricsCoordinator.recordTreeUpdate(root: root, nodeCount: nodes.count)

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
}
