import EasyBarShared
import Foundation

/// Streams Wi-Fi and network state from the network agent.
final class NetworkAgentClient {
  /// Shared network-agent client.
  static var shared = NetworkAgentClient(
    logger: ProcessLogger(label: "easybar.bootstrap.network_agent"),
    config: .shared
  )

  /// Configures the shared network-agent client.
  static func bootstrap(logger: ProcessLogger, config: Config = .shared) {
    shared = NetworkAgentClient(logger: logger, config: config)
  }

  /// Logger used for network-agent diagnostics.
  private let logger: ProcessLogger
  private let config: Config
  /// Whether the client lifecycle is active.
  private var started = false

  /// Wake-triggered refresh controller.
  private lazy var wakeRefreshController = AgentWakeRefreshController(
    label: "network agent client",
    logger: logger.child("wake_refresh")
  )

  /// Socket client that owns the network-agent stream.
  private lazy var client = AgentSocketClient<NetworkAgentRequest, NetworkAgentMessage>(
    label: "network agent client",
    socketPath: { [config] in config.networkAgentSocketPath },
    subscribeRequest: {
      NetworkAgentRequest(command: .subscribe, fields: NativeWiFiRequestedFields.snapshot)
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: { [weak self] in
      self?.handleDisconnectedStateReset()
    },
    onConnected: {
      MetricsCoordinator.shared.recordAgentConnected(.network)
    },
    onDisconnected: {
      MetricsCoordinator.shared.recordAgentDisconnected(.network)
    },
    onDecodedMessage: {
      MetricsCoordinator.shared.recordAgentMessage(.network)
    },
    onDecodeError: {
      MetricsCoordinator.shared.recordAgentDecodeError(.network)
    },
    logger: logger.child("socket_client")
  )

  /// Creates the shared network-agent client.
  init(logger: ProcessLogger, config: Config) {
    self.logger = logger
    self.config = config
  }

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    return client.isConnected
  }

  /// Starts the network agent client.
  func start() {
    guard !started else { return }

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

    MetricsCoordinator.shared.recordAgentRefresh(.network)
    client.refresh()
  }

  /// Handles one decoded network agent message.
  private func handle(_ message: NetworkAgentMessage) {
    guard started else { return }

    switch message.kind {
    case .version:
      break

    case .subscribed:
      logger.info("network agent client subscribed")

    case .fields:
      guard let fields = message.fields else {
        logger.warn("network agent returned fields message without payload")
        return
      }

      guard let snapshot = NetworkAgentSnapshot(fields: fields) else {
        logger.warn("network agent returned incomplete field set")
        return
      }

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

    logger.warn(
      "network agent error",
      .field("code", code?.rawValue ?? "unknown"),
      .field("message", message ?? "unknown)"),
    )

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
    clearPublishedState(notify: true)
  }

  /// Clears the shared Wi-Fi state and optionally emits the corresponding app events.
  private func clearPublishedState(notify: Bool) {
    DispatchQueue.main.async {
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
    DispatchQueue.main.async {
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
