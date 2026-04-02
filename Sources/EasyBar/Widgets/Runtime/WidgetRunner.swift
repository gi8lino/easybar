import Foundation

final class WidgetRunner {
  private static let initialEvents: [(name: String, event: AppEvent)] = [
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
  ]

  static let shared = WidgetRunner()

  private let decoder = JSONDecoder()

  private var runtimeState = WidgetRuntimeState()
  private var started = false
  private var stdoutObserver: NSObjectProtocol?

  private init() {}

  /// Starts the widget runtime and begins observing Lua stdout.
  func start() {
    guard !started else {
      Logger.debug("widget runner already started")
      return
    }

    started = true
    resetRuntimeState()

    Logger.debug("starting widget runner")
    startObservingRuntimeOutput()
    LuaRuntime.shared.start()
  }

  /// Reloads the Lua runtime and clears rendered widget state.
  func reload() {
    Logger.debug("reloading widget runner")

    shutdown()
    WidgetStore.shared.clear()
    start()
  }

  /// Stops the widget runtime and related event sources.
  func shutdown() {
    Logger.debug("shutting down widget runner")
    stopObservingRuntimeOutput()

    started = false
    resetRuntimeState()

    EventManager.shared.stopAll()
    LuaRuntime.shared.shutdown()
  }

  /// Handles one line of structured stdout from the Lua runtime.
  private func handleRuntimeOutput(_ line: String) {
    Logger.debug("lua stdout: \(line)")

    do {
      let update = try decodeUpdate(from: line)
      handleUpdate(update, rawLine: line)
    } catch DecodingError.dataCorrupted {
      Logger.warn("invalid utf8: \(line)")
    } catch {
      Logger.warn("json decode failed: \(line)")
      Logger.debug("decode error: \(error)")
    }
  }

  /// Starts observing structured stdout from the Lua runtime.
  private func startObservingRuntimeOutput() {
    stdoutObserver = NotificationCenter.default.addObserver(
      forName: .easyBarLuaStdout,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let line = notification.object as? String else { return }
      self?.handleRuntimeOutput(line)
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
    Logger.debug("emitting initial widget events")

    for (name, event) in Self.initialEvents {
      emitInitialEvent(named: name, event: event)
    }

    EventBus.shared.emit(.forced)
  }

  /// Handles one decoded Lua runtime update.
  private func handleUpdate(_ update: WidgetTreeUpdate, rawLine: String) {
    guard !update.isSubscriptions else {
      handleSubscriptions(update)
      return
    }

    guard !update.isReady else {
      handleReady()
      return
    }

    guard update.isTree else {
      Logger.warn("unknown lua message: \(rawLine)")
      return
    }

    handleTree(update, rawLine: rawLine)
  }

  /// Handles one subscription update from Lua.
  private func handleSubscriptions(_ update: WidgetTreeUpdate) {
    runtimeState.requiredEvents = Set(update.subscribedEvents)
    runtimeState.hasSubscriptions = true

    Logger.debug("required events: \(runtimeState.requiredEvents)")
    EventManager.shared.start(subscriptions: runtimeState.requiredEvents)
    emitInitialEventsIfPossible()
  }

  /// Handles the Lua runtime ready handshake.
  private func handleReady() {
    Logger.debug("lua runtime handshake received")
    runtimeState.isReady = true
    emitInitialEventsIfPossible()
  }

  /// Handles one rendered widget tree update.
  private func handleTree(_ update: WidgetTreeUpdate, rawLine: String) {
    guard let tree = update.treePayload else {
      Logger.warn("unknown lua message: \(rawLine)")
      return
    }

    Logger.debug("decoded widget tree root=\(tree.root) nodes=\(tree.nodes.count)")
    WidgetStore.shared.apply(root: tree.root, nodes: tree.nodes)
  }

  /// Emits one initial event when Lua subscribed to it.
  private func emitInitialEvent(named name: String, event: AppEvent) {
    guard runtimeState.requiredEvents.contains(name) else { return }
    EventBus.shared.emit(event)
  }

  /// Resets Lua runtime handshake and subscription state.
  private func resetRuntimeState() {
    runtimeState.reset()
  }
}
