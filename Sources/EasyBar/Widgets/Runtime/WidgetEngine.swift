import Foundation

/// Actor-owned widget runtime coordinator.
///
/// This replaces direct ownership in `WidgetRunner` while keeping a small
/// compatibility façade so the rest of the app can migrate incrementally.
actor WidgetEngine {
  static let shared = WidgetEngine()

  private static let outputProcessingQueue = DispatchQueue(
    label: "easybar.widget-engine.output",
    qos: .userInitiated
  )

  private let decoder = JSONDecoder()

  private var runtimeState = WidgetRuntimeState()
  private var started = false
  private var stdoutObserver: NSObjectProtocol?

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

  /// Starts the widget runtime and begins observing Lua stdout.
  func start() async {
    guard !started else {
      easybarLog.debug("widget engine already started")
      return
    }

    easybarLog.debug("widget engine start begin")

    started = true
    resetRuntimeState()
    startObservingRuntimeOutput()
    await LuaRuntime.shared.start()

    easybarLog.debug("widget engine start end")
  }

  /// Reloads the Lua runtime and clears rendered widget state.
  func reload() async {
    easybarLog.debug("widget engine reload begin")

    await shutdown()
    await MainActor.run {
      WidgetStore.shared.clear()
    }
    await start()

    easybarLog.debug("widget engine reload end")
  }

  /// Stops the widget runtime and related event sources.
  func shutdown() async {
    guard started else {
      easybarLog.debug("widget engine shutdown skipped, not started")
      return
    }

    easybarLog.debug("widget engine shutdown begin")

    stopObservingRuntimeOutput()

    started = false
    resetRuntimeState()

    EventManager.shared.stopAll()
    await LuaRuntime.shared.shutdown()

    easybarLog.debug("widget engine shutdown end")
  }

  /// Resets Lua runtime handshake and subscription state.
  private func resetRuntimeState() {
    runtimeState.reset()
  }

  /// Handles one line of structured stdout from the Lua runtime.
  private func handleRuntimeOutput(_ line: String) {
    easybarLog.debug("lua stdout: \(line)")

    Self.outputProcessingQueue.async { [weak self] in
      guard let self else { return }

      Task {
        guard await self.started else { return }

        do {
          let update = try self.decodeUpdate(from: line)
          await self.handleUpdate(update, rawLine: line)
        } catch DecodingError.dataCorrupted {
          MetricsCoordinator.shared.recordDecodeError()
          easybarLog.warn("invalid utf8: \(line)")
        } catch {
          MetricsCoordinator.shared.recordDecodeError()
          easybarLog.warn("json decode failed: \(line)")
          easybarLog.debug("decode error: \(error)")
        }
      }
    }
  }

  /// Starts observing structured stdout from the Lua runtime.
  private func startObservingRuntimeOutput() {
    stopObservingRuntimeOutput()

    stdoutObserver = NotificationCenter.default.addObserver(
      forName: .easyBarLuaStdout,
      object: nil,
      queue: nil
    ) { [weak self] notification in
      guard let self else { return }
      guard let line = notification.object as? String else { return }

      self.handleRuntimeOutput(line)
    }
  }

  /// Stops observing structured stdout from the Lua runtime.
  private func stopObservingRuntimeOutput() {
    guard let stdoutObserver else { return }
    NotificationCenter.default.removeObserver(stdoutObserver)
    self.stdoutObserver = nil
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
  private func emitInitialEventsIfPossible() {
    guard runtimeState.canEmitInitialEvents else { return }
    runtimeState.didEmitInitialEvents = true
    emitInitialEvents()
  }

  /// Emits initial state-refresh events required by subscribed widgets.
  private func emitInitialEvents() {
    easybarLog.debug("emitting initial widget events")

    for (name, event) in Self.initialEvents {
      emitInitialEvent(named: name, event: event)
    }

    EventBus.shared.emit(.manualRefresh)
  }

  /// Handles one decoded Lua runtime update.
  private func handleUpdate(_ update: WidgetTreeUpdate, rawLine: String) async {
    guard !update.isSubscriptions else {
      handleSubscriptions(update)
      return
    }

    guard !update.isReady else {
      handleReady()
      return
    }

    guard update.isTree else {
      easybarLog.warn("unknown lua message: \(rawLine)")
      return
    }

    await handleTree(update, rawLine: rawLine)
  }

  /// Handles one subscription update from Lua.
  private func handleSubscriptions(_ update: WidgetTreeUpdate) {
    runtimeState.requiredEvents = Set(update.subscribedEvents)
    runtimeState.hasSubscriptions = true

    MetricsCoordinator.shared.recordLuaSubscriptions(runtimeState.requiredEvents)
    easybarLog.debug("required events: \(runtimeState.requiredEvents)")
    EventManager.shared.start(subscriptions: runtimeState.requiredEvents)
    emitInitialEventsIfPossible()
  }

  /// Handles the Lua runtime ready handshake.
  private func handleReady() {
    easybarLog.debug("lua runtime handshake received")
    runtimeState.isReady = true
    MetricsCoordinator.shared.recordLuaReady()
    emitInitialEventsIfPossible()
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
  private func emitInitialEvent(named name: String, event: AppEvent) {
    guard runtimeState.requiredEvents.contains(name) else { return }

    switch event {
    case .networkChange:
      let isTunnel = NativeWiFiStore.shared.snapshot?.primaryInterfaceIsTunnel ?? false
      EventBus.shared.emit(.networkChange, primaryInterfaceIsTunnel: isTunnel)

    case .wifiChange:
      if let interfaceName = NativeWiFiStore.shared.snapshot?.interfaceName, !interfaceName.isEmpty
      {
        EventBus.shared.emit(.wifiChange, interfaceName: interfaceName)
      } else {
        EventBus.shared.emit(.wifiChange)
      }

    default:
      EventBus.shared.emit(event)
    }
  }
}
