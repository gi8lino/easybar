import Foundation

/// Actor-owned scripted widget runtime.
///
/// This actor owns the Lua handshake state, subscriptions, and tree updates.
actor WidgetEngine {
  static let shared = WidgetEngine()

  private let decoder = JSONDecoder()

  private var runtimeState = WidgetRuntimeState()
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

    await shutdown()

    await MainActor.run {
      WidgetStore.shared.clear()
    }

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
      EventManager.shared.stopAll()
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
    await emitInitialEvents()
  }

  /// Emits initial state-refresh events required by subscribed widgets.
  private func emitInitialEvents() async {
    easybarLog.debug("emitting initial widget events")

    for (name, event) in Self.initialEvents {
      await emitInitialEvent(named: name, event: event)
    }

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

    easybarLog.debug("decoded widget tree root=\(tree.root) nodes=\(tree.nodes.count)")
    MetricsCoordinator.shared.recordTreeUpdate(root: tree.root, nodeCount: tree.nodes.count)

    await MainActor.run {
      WidgetStore.shared.apply(root: tree.root, nodes: tree.nodes)
    }
  }

  /// Emits one initial event when Lua subscribed to it.
  private func emitInitialEvent(named name: String, event: AppEvent) async {
    guard runtimeState.requiredEvents.contains(name) else { return }

    switch event {
    case .networkChange:
      let isTunnel = await MainActor.run {
        NativeWiFiStore.shared.snapshot?.primaryInterfaceIsTunnel ?? false
      }
      await EventHub.shared.emit(.networkChange, primaryInterfaceIsTunnel: isTunnel)

    case .wifiChange:
      let interfaceName = await MainActor.run {
        NativeWiFiStore.shared.snapshot?.interfaceName
      }

      if let interfaceName, !interfaceName.isEmpty {
        await EventHub.shared.emit(.wifiChange, interfaceName: interfaceName)
      } else {
        await EventHub.shared.emit(.wifiChange)
      }

    default:
      await EventHub.shared.emit(event)
    }
  }
}

extension WidgetEngine {
  static let initialEvents: [(name: String, event: AppEvent)] = [
    ("system_woke", .systemWoke),
    ("power_source_change", .powerSourceChange),
    ("charging_state_change", .chargingStateChange),
    ("wifi_change", .wifiChange),
    ("network_change", .networkChange),
    ("volume_change", .volumeChange),
    ("mute_change", .muteChange),
    ("calendar_change", .calendarChange),
    ("minute_tick", .minuteTick),
    ("second_tick", .secondTick),
    ("focus_change", .focusChange),
    ("workspace_change", .workspaceChange),
    ("space_mode_change", .spaceModeChange),
  ]
}
