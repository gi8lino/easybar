import Foundation

/// Actor-owned scripted widget runtime.
///
/// This actor owns the Lua handshake state, subscriptions, and tree updates.
actor WidgetEngine {
  static let shared = WidgetEngine()

  private let decoder = JSONDecoder()

  private var runtimeState = WidgetRuntimeState()
  private var scriptedRoots = Set<String>()
  private var started = false

  /// Starts the scripted widget runtime.
  func start() async {
    guard !started else {
      easybarLog.debug("widget engine already started")
      return
    }

    easybarLog.debug("widget engine start begin")

    started = true
    runtimeState.reset()
    EventCatalog.validateLuaDefinitions()

    await LuaRuntime.shared.setStdoutHandler { line in
      Task {
        await WidgetEngine.shared.handleRuntimeOutput(line)
      }
    }

    await LuaRuntime.shared.start()

    easybarLog.debug("widget engine start end")
  }

  /// Reloads the scripted widget runtime and clears rendered state.
  func reload() async {
    easybarLog.debug("widget engine reload begin")

    let rootsToClear = scriptedRoots
    await shutdown()

    await MainActor.run {
      WidgetStore.shared.clear(roots: rootsToClear)
    }

    scriptedRoots.removeAll()
    await start()

    easybarLog.debug("widget engine reload end")
  }

  /// Stops the scripted widget runtime and event sources.
  func shutdown() async {
    guard started else {
      easybarLog.debug("widget engine shutdown skipped, not started")
      return
    }

    easybarLog.debug("widget engine shutdown begin")

    started = false
    runtimeState.reset()

    await MainActor.run {
      EventManager.shared.stopLuaSubscriptions()
    }

    await LuaRuntime.shared.shutdown()

    easybarLog.debug("widget engine shutdown end")
  }

  /// Handles one line of structured stdout from the Lua runtime.
  func handleRuntimeOutput(_ line: String) async {
    guard started else { return }

    easybarLog.debug("lua stdout: \(line)")

    do {
      let update = try decodeUpdate(from: line)
      await handleUpdate(update, rawLine: line)
    } catch DecodingError.dataCorrupted {
      MetricsCoordinator.shared.recordDecodeError()
      easybarLog.warn("invalid utf8: \(line)")
    } catch {
      MetricsCoordinator.shared.recordDecodeError()
      easybarLog.warn("json decode failed: \(line)")
      easybarLog.debug("decode error: \(error)")
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
    easybarLog.debug("emitting replayable widget events")
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

    guard update.isTree else {
      easybarLog.warn("unknown lua message: \(rawLine)")
      return
    }

    await handleTree(update, rawLine: rawLine)
  }

  /// Handles one subscription update from Lua.
  private func handleSubscriptions(_ update: WidgetTreeUpdate) async {
    runtimeState.requiredEvents = Set(update.subscribedEvents)
    runtimeState.hasSubscriptions = true

    MetricsCoordinator.shared.recordLuaSubscriptions(runtimeState.requiredEvents)
    easybarLog.debug("required events: \(runtimeState.requiredEvents)")

    let requiredEvents = runtimeState.requiredEvents
    await MainActor.run {
      EventManager.shared.start(subscriptions: requiredEvents)
    }

    await emitInitialEventsIfPossible()
  }

  /// Handles the Lua runtime ready handshake.
  private func handleReady() async {
    easybarLog.debug("lua runtime handshake received")
    runtimeState.isReady = true
    MetricsCoordinator.shared.recordLuaReady()
    await emitInitialEventsIfPossible()
  }

  /// Handles one rendered widget tree update.
  private func handleTree(_ update: WidgetTreeUpdate, rawLine: String) async {
    guard let tree = update.treePayload else {
      easybarLog.warn("unknown lua message: \(rawLine)")
      return
    }

    scriptedRoots.insert(tree.root)
    easybarLog.debug("decoded widget tree root=\(tree.root) nodes=\(tree.nodes.count)")
    MetricsCoordinator.shared.recordTreeUpdate(root: tree.root, nodeCount: tree.nodes.count)

    await MainActor.run {
      WidgetStore.shared.apply(root: tree.root, nodes: tree.nodes)
    }
  }
}
