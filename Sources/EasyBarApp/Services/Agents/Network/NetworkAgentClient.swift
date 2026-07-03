import EasyBarShared
import Foundation

/// Streams Wi-Fi and network state from the network agent.
final class NetworkAgentClient {
  private struct ErrorLogKey: Equatable {
    let code: String
    let message: String
  }

  private struct ErrorLogState {
    var lastKey: ErrorLogKey?
    var repeatCount = 0
  }

  /// Shared network-agent client.
  static var shared = NetworkAgentClient(
    logger: ProcessLogger(label: "easybar.bootstrap.network_agent"),
    config: Config.makeUnloadedConfig().snapshot().networkAgent,
    metricsCoordinator: .shared
  )

  /// Logger used for network-agent diagnostics.
  private let logger: ProcessLogger
  /// Metrics recorder for network-agent lifecycle and messages.
  private let metricsCoordinator: MetricsCoordinator
  /// Active network-agent config snapshot.
  private var config: ConfigSnapshot.NetworkAgent
  /// Whether the client lifecycle is active.
  private var started = false
  /// Last logged network-agent error, used to suppress identical repeats.
  private let errorLogState = LockedState(ErrorLogState())

  /// Wake-triggered refresh controller.
  private lazy var wakeRefreshController = AgentWakeRefreshController(
    label: "network agent client",
    logger: logger.child("wake_refresh")
  )

  /// Socket client that owns the network-agent stream.
  private lazy var client = AgentSocketClient<NetworkAgentRequest, NetworkAgentMessage>(
    label: "network agent client",
    socketPath: { [weak self] in self?.config.socketPath ?? "" },
    subscribeRequest: {
      NetworkAgentRequest(command: .subscribe, fields: NetworkAgentSnapshot.snapshotFieldSet)
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: { [weak self] in
      self?.handleDisconnectedStateReset()
    },
    onConnected: { [weak self] in
      guard let self else { return }
      Task {
        await self.metricsCoordinator.recordAgentConnected(.network)
      }
    },
    onDisconnected: { [weak self] in
      guard let self else { return }
      Task {
        await self.metricsCoordinator.recordAgentDisconnected(.network)
      }
    },
    onDecodedMessage: { [weak self] in
      guard let self else { return }
      Task {
        await self.metricsCoordinator.recordAgentMessage(.network)
      }
    },
    onDecodeError: { [weak self] in
      guard let self else { return }
      Task {
        await self.metricsCoordinator.recordAgentDecodeError(.network)
      }
    },
    logger: logger.child("socket_client")
  )

  /// Creates the shared network-agent client.
  init(
    logger: ProcessLogger,
    config: ConfigSnapshot.NetworkAgent,
    metricsCoordinator: MetricsCoordinator = .shared
  ) {
    self.logger = logger
    self.config = config
    self.metricsCoordinator = metricsCoordinator
  }

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    return client.isConnected
  }

  /// Replaces the active network-agent config snapshot.
  func updateConfiguration(_ config: ConfigSnapshot.NetworkAgent) {
    let socketPathChanged = self.config.socketPath != config.socketPath
    let enabledChanged = self.config.enabled != config.enabled
    self.config = config

    guard started, socketPathChanged || enabledChanged else { return }

    logger.debug(
      "network agent config changed; restarting client",
      .field("socket", config.socketPath),
      .field("enabled", config.enabled)
    )

    client.stop()

    guard config.enabled else {
      started = false
      wakeRefreshController.stop()
      clearPublishedState(notify: true)
      return
    }

    client.start()
  }

  /// Starts the network agent client.
  func start() {
    guard !started else { return }

    guard config.enabled else {
      logger.debug("network agent client start skipped because agent is disabled")
      clearPublishedState(notify: false)
      return
    }

    started = true

    wakeRefreshController.start { [weak self] in
      guard let self, self.started else { return }
      self.refresh()
    }

    client.start()
  }

  /// Stops the network agent client.
  func stop() {
    guard started else { return }

    started = false

    wakeRefreshController.stop()
    client.stop()
    clearPublishedState(notify: false)
  }

  /// Requests one fresh network-agent update using the current subscription.
  func refresh() {
    guard started else { return }

    logger.debug("network agent client manual refresh")

    Task {
      await metricsCoordinator.recordAgentRefresh(.network)
    }
    client.refresh()
  }

  /// Handles one decoded network agent message.
  private func handle(_ message: NetworkAgentMessage) {
    guard started else { return }

    switch message.kind {
    case .version:
      break

    case .subscribed:
      logger.debug("network agent client subscribed")

    case .fields:
      guard let fields = message.fields else {
        logger.warn("network agent returned fields message without payload")
        return
      }

      guard let snapshot = NetworkAgentSnapshot(fields: fields) else {
        logger.warn("network agent returned incomplete field set")
        return
      }

      resetErrorLogState()
      publish(snapshot: snapshot)

    case .pong:
      break

    case .error:
      handleError(code: message.errorCode, message: message.message)
    }
  }

  /// Handles one network-agent error message.
  private func handleError(code: NetworkAgentErrorCode?, message: String?) {
    guard started else { return }

    logAgentErrorIfNeeded(code: code, message: message)

    guard code == .permissionDenied else { return }

    publish(
      snapshot: NetworkAgentSnapshot(
        accessGranted: false,
        permissionState: "denied",
        generatedAt: Date(),
        ssid: nil,
        ipv4Address: nil,
        ipv6Address: nil,
        bssid: nil,
        interfaceName: nil,
        hardwareAddress: nil,
        power: nil,
        serviceActive: nil,
        primaryInterfaceIsTunnel: false,
        rssi: nil,
        noise: nil,
        snr: nil,
        linkQuality: nil,
        txRate: nil,
        channel: nil,
        channelBand: nil,
        channelWidth: nil,
        security: nil,
        phyMode: nil,
        interfaceMode: nil,
        countryCode: nil,
        roaming: nil,
        ssidChangedAt: nil,
        interfaceChangedAt: nil
      )
    )
  }

  /// Handles a socket disconnect by clearing published state.
  private func handleDisconnectedStateReset() {
    guard started else { return }
    resetErrorLogState()
    clearPublishedState(notify: true)
  }

  /// Logs the first instance of an agent error, then suppresses identical repeats.
  private func logAgentErrorIfNeeded(code: NetworkAgentErrorCode?, message: String?) {
    let key = ErrorLogKey(code: code?.rawValue ?? "unknown", message: message ?? "unknown")
    let decision = errorLogState.withLock { state -> (shouldLog: Bool, repeatCount: Int) in
      guard state.lastKey == key else {
        state.lastKey = key
        state.repeatCount = 0
        return (true, 0)
      }

      state.repeatCount += 1
      return (state.repeatCount % 25 == 0, state.repeatCount)
    }

    guard decision.shouldLog else { return }

    if decision.repeatCount > 0 {
      logger.warn(
        "network agent error",
        .field("code", key.code),
        .field("message", key.message),
        .field("repeat_count", decision.repeatCount),
      )
      return
    }

    logger.warn(
      "network agent error",
      .field("code", key.code),
      .field("message", key.message),
    )
  }

  /// Allows the next network-agent error after a successful update to be logged.
  private func resetErrorLogState() {
    errorLogState.withLock { state in
      state.lastKey = nil
      state.repeatCount = 0
    }
  }

  /// Clears the shared Wi-Fi state and optionally emits the corresponding app events.
  private func clearPublishedState(notify: Bool) {
    Task { @MainActor in
      let previous = NativeWiFiStore.shared.snapshot
      let changed = NativeWiFiStore.shared.clear()

      guard changed else { return }
      guard notify else { return }

      Task {
        await EventHub.shared.emit(
          .networkChange,
          primaryInterfaceIsTunnel: false
        )

        if self.shouldEmitWiFiChangeAfterReset(previous: previous) {
          await EventHub.shared.emit(.wifiChange)
        }
      }
    }
  }

  /// Publishes one snapshot to the shared store on the main queue and emits app events.
  private func publish(snapshot: NetworkAgentSnapshot) {
    Task { @MainActor in
      guard self.started else { return }

      let previous = NativeWiFiStore.shared.snapshot
      let changed = NativeWiFiStore.shared.apply(snapshot: snapshot)

      guard changed else { return }

      Task {
        await EventHub.shared.emit(
          .networkChange,
          primaryInterfaceIsTunnel: snapshot.primaryInterfaceIsTunnel
        )

        let ssidChanged = previous?.ssid != snapshot.ssid
        let interfaceChanged = previous?.interfaceName != snapshot.interfaceName

        guard ssidChanged || interfaceChanged else { return }

        if let interfaceName = snapshot.interfaceName, !interfaceName.isEmpty {
          await EventHub.shared.emit(.wifiChange, interfaceName: interfaceName)
        } else {
          await EventHub.shared.emit(.wifiChange)
        }
      }
    }
  }

  /// Returns whether clearing the published state should also emit a Wi-Fi change event.
  private func shouldEmitWiFiChangeAfterReset(previous: NetworkAgentSnapshot?) -> Bool {
    return previous?.ssid != nil || previous?.interfaceName != nil
  }
}
