import EasyBarShared
import Foundation

final class NetworkAgentClient {
  private static var sharedInstance: NetworkAgentClient?

  /// Returns the configured shared network-agent client.
  static var shared: NetworkAgentClient {
    guard let sharedInstance else {
      fatalError(
        "NetworkAgentClient.bootstrap(logger:) must be called before NetworkAgentClient.shared")
    }

    return sharedInstance
  }

  /// Configures the shared network-agent client.
  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = NetworkAgentClient(logger: logger)
  }

  private let logger: ProcessLogger
  private var started = false

  private lazy var wakeRefreshController = AgentWakeRefreshController(
    label: "network agent client",
    logger: logger.child("wake_refresh")
  )

  private lazy var client = AgentSocketClient<NetworkAgentRequest, NetworkAgentMessage>(
    label: "network agent client",
    socketPath: { Config.shared.networkAgentSocketPath },
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

  private init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    client.isConnected
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
      "code", code?.rawValue ?? "unknown",
      "message", message ?? "unknown"
    )

    guard code == .permissionDenied else { return }

    publish(
      snapshot: NetworkAgentSnapshot(
        accessGranted: false,
        permissionState: "denied",
        generatedAt: Date(),
        ssid: nil,
        interfaceName: nil,
        primaryInterfaceIsTunnel: false,
        rssi: nil
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

        if previous?.ssid != nil || previous?.interfaceName != nil {
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
}
