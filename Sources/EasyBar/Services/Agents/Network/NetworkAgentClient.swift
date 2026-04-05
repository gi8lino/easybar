import EasyBarShared
import Foundation

final class NetworkAgentClient {
  static let shared = NetworkAgentClient()

  private lazy var client = AgentSocketClient<NetworkAgentRequest, NetworkAgentMessage>(
    label: "network agent client",
    socketPath: { Config.shared.networkAgentSocketPath },
    subscribeRequest: {
      NetworkAgentRequest(command: .subscribe, fields: NativeWiFiRequestedFields.snapshot)
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: {
      DispatchQueue.main.async {
        NativeWiFiStore.shared.clear()
      }
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
    client.start()
  }

  /// Stops the network agent client.
  func stop() {
    client.stop()
  }

  /// Handles one decoded network agent message.
  private func handle(_ message: NetworkAgentMessage) {
    switch message.kind {
    case .subscribed:
      easybarLog.info("network agent client subscribed")

    case .fields:
      guard let fields = message.fields else { return }
      guard let snapshot = NetworkAgentSnapshot(fields: fields) else {
        easybarLog.warn("network agent returned incomplete field set")
        return
      }

      publish(snapshot: snapshot)

    case .pong:
      break

    case .error:
      handleError(message.message ?? "unknown")
    }
  }

  /// Handles one network-agent error message.
  private func handleError(_ message: String) {
    easybarLog.warn("network agent error=\(message)")

    guard message.hasPrefix("permission_denied") else { return }

    let permissionState =
      message.split(separator: ":", maxSplits: 1).dropFirst().first.map(String.init) ?? "denied"

    publish(
      snapshot: NetworkAgentSnapshot(
        accessGranted: false,
        permissionState: permissionState,
        generatedAt: Date(),
        ssid: nil,
        interfaceName: nil,
        primaryInterfaceIsTunnel: false,
        rssi: nil
      )
    )
  }

  /// Publishes one snapshot to the shared store on the main queue.
  private func publish(snapshot: NetworkAgentSnapshot) {
    DispatchQueue.main.async {
      NativeWiFiStore.shared.apply(snapshot: snapshot)
    }
  }
}
