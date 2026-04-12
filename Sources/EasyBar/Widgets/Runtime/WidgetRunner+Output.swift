import Foundation

extension WidgetRunner {

  /// Handles one line of structured stdout from the Lua runtime.
  func handleRuntimeOutput(_ line: String) {
    easybarLog.debug("lua stdout: \(line)")

    do {
      let update = try decodeUpdate(from: line)
      handleUpdate(update, rawLine: line)
    } catch DecodingError.dataCorrupted {
      MetricsCoordinator.shared.recordDecodeError()
      easybarLog.warn("invalid utf8: \(line)")
    } catch {
      MetricsCoordinator.shared.recordDecodeError()
      easybarLog.warn("json decode failed: \(line)")
      easybarLog.debug("decode error: \(error)")
    }
  }

  /// Starts observing structured stdout from the Lua runtime.
  func startObservingRuntimeOutput() {
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
  func stopObservingRuntimeOutput() {
    guard let stdoutObserver else { return }
    NotificationCenter.default.removeObserver(stdoutObserver)
    self.stdoutObserver = nil
  }

  /// Decodes one structured runtime update line.
  func decodeUpdate(from line: String) throws -> WidgetTreeUpdate {
    guard let data = line.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: [], debugDescription: "invalid utf8")
      )
    }

    return try decoder.decode(WidgetTreeUpdate.self, from: data)
  }

  /// Emits initial events after both subscriptions and readiness are known.
  func emitInitialEventsIfPossible() {
    guard runtimeState.canEmitInitialEvents else { return }
    runtimeState.didEmitInitialEvents = true
    emitInitialEvents()
  }

  /// Emits initial state-refresh events required by subscribed widgets.
  func emitInitialEvents() {
    easybarLog.debug("emitting initial widget events")

    for (name, event) in Self.initialEvents {
      emitInitialEvent(named: name, event: event)
    }

    EventBus.shared.emit(.manualRefresh)
  }

  /// Handles one decoded Lua runtime update.
  func handleUpdate(_ update: WidgetTreeUpdate, rawLine: String) {
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

    handleTree(update, rawLine: rawLine)
  }

  /// Handles one subscription update from Lua.
  func handleSubscriptions(_ update: WidgetTreeUpdate) {
    runtimeState.requiredEvents = Set(update.subscribedEvents)
    runtimeState.hasSubscriptions = true

    MetricsCoordinator.shared.recordLuaSubscriptions(runtimeState.requiredEvents)
    easybarLog.debug("required events: \(runtimeState.requiredEvents)")
    EventManager.shared.start(subscriptions: runtimeState.requiredEvents)
    emitInitialEventsIfPossible()
  }

  /// Handles the Lua runtime ready handshake.
  func handleReady() {
    easybarLog.debug("lua runtime handshake received")
    runtimeState.isReady = true
    MetricsCoordinator.shared.recordLuaReady()
    emitInitialEventsIfPossible()
  }

  /// Handles one rendered widget tree update.
  func handleTree(_ update: WidgetTreeUpdate, rawLine: String) {
    guard let tree = update.treePayload else {
      easybarLog.warn("unknown lua message: \(rawLine)")
      return
    }

    easybarLog.debug("decoded widget tree root=\(tree.root) nodes=\(tree.nodes.count)")
    MetricsCoordinator.shared.recordTreeUpdate(root: tree.root, nodeCount: tree.nodes.count)
    WidgetStore.shared.apply(root: tree.root, nodes: tree.nodes)
  }

  /// Emits one initial event when Lua subscribed to it.
  func emitInitialEvent(named name: String, event: AppEvent) {
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
