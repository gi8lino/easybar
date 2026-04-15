import EasyBarShared
import Foundation

final class NetworkAgentClient {
  static let shared = NetworkAgentClient()

  private let eventObserver = EasyBarEventObserver()
  private let refreshQueue = DispatchQueue(label: "easybar.network-agent.refresh")
  private var pendingWakeRefreshWorkItem: DispatchWorkItem?

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
      self?.clearPublishedState()
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
    debugLog: easybarLog.debug,
    infoLog: easybarLog.info,
    warnLog: easybarLog.warn,
    errorLog: easybarLog.error
  )

  private init() {}

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    client.isConnected
  }

  /// Starts the network agent client.
  func start() {
    startEventObserver()
    client.start()
  }

  /// Stops the network agent client.
  func stop() {
    pendingWakeRefreshWorkItem?.cancel()
    pendingWakeRefreshWorkItem = nil
    eventObserver.stop()
    client.stop()
  }

  /// Requests one fresh network-agent update using the current subscription.
  func refresh() {
    easybarLog.debug("network agent client manual refresh")
    MetricsCoordinator.shared.recordAgentRefresh(.network)
    client.refresh()
  }

  /// Starts shared app-event observation needed by the network agent client.
  private func startEventObserver() {
    eventObserver.start { [weak self] payload in
      guard let self else { return }
      guard let event = payload.appEvent else { return }
      guard event == .systemWoke else { return }

      self.scheduleWakeRefresh()
    }
  }

  /// Coalesces wake-triggered refresh work into one refresh request.
  private func scheduleWakeRefresh() {
    pendingWakeRefreshWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      easybarLog.debug("network agent client refreshing after system_woke")
      self.refresh()
    }

    pendingWakeRefreshWorkItem = workItem
    refreshQueue.asyncAfter(deadline: .now() + 0.20, execute: workItem)
  }

  /// Handles one decoded network agent message.
  private func handle(_ message: NetworkAgentMessage) {
    switch message.kind {
    case .version:
      break

    case .subscribed:
      easybarLog.info("network agent client subscribed")

    case .fields:
      guard let fields = message.fields else {
        easybarLog.warn("network agent returned fields message without payload")
        return
      }

      guard let snapshot = NetworkAgentSnapshot(fields: fields) else {
        easybarLog.warn("network agent returned incomplete field set")
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
    easybarLog.warn(
      "network agent error code=\(code?.rawValue ?? "unknown") message=\(message ?? "unknown")"
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

  /// Clears the shared Wi-Fi state and emits the corresponding app events.
  private func clearPublishedState() {
    DispatchQueue.main.async {
      let previous = NativeWiFiStore.shared.snapshot
      let changed = NativeWiFiStore.shared.clear()

      guard changed else { return }

      EventBus.shared.emit(
        .networkChange,
        primaryInterfaceIsTunnel: false
      )

      if previous?.ssid != nil || previous?.interfaceName != nil {
        EventBus.shared.emit(.wifiChange)
      }
    }
  }

  /// Publishes one snapshot to the shared store on the main queue and emits app events.
  private func publish(snapshot: NetworkAgentSnapshot) {
    DispatchQueue.main.async {
      let previous = NativeWiFiStore.shared.snapshot
      let changed = NativeWiFiStore.shared.apply(snapshot: snapshot)

      guard changed else { return }

      EventBus.shared.emit(
        .networkChange,
        primaryInterfaceIsTunnel: snapshot.primaryInterfaceIsTunnel
      )

      let ssidChanged = previous?.ssid != snapshot.ssid
      let interfaceChanged = previous?.interfaceName != snapshot.interfaceName

      guard ssidChanged || interfaceChanged else { return }

      if let interfaceName = snapshot.interfaceName, !interfaceName.isEmpty {
        EventBus.shared.emit(.wifiChange, interfaceName: interfaceName)
      } else {
        EventBus.shared.emit(.wifiChange)
      }
    }
  }
}
