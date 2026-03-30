import EasyBarShared
import Foundation

final class NetworkAgentClient {
  static let shared = NetworkAgentClient()
  private static let requestedFields: [NetworkAgentField] = [
    .locationAuthorized,
    .locationPermissionState,
    .generatedAt,
    .ssid,
    .interfaceName,
    .primaryInterfaceIsTunnel,
    .rssi,
  ]

  private lazy var client = AgentSocketClient<NetworkAgentRequest, NetworkAgentMessage>(
    label: "network agent client",
    socketPath: { Config.shared.networkAgentSocketPath },
    subscribeRequest: {
      NetworkAgentRequest(command: .subscribe, fields: Self.requestedFields)
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: {
      DispatchQueue.main.async {
        NativeWiFiStore.shared.clear()
      }
    }
  )

  private init() {}

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    client.isConnected
  }

  func start() {
    client.start()
  }

  func stop() {
    client.stop()
  }

  private func handle(_ message: NetworkAgentMessage) {
    switch message.kind {
    case .subscribed:
      Logger.info("network agent client subscribed")

    case .fields:
      guard let fields = message.fields else { return }
      guard let snapshot = NetworkAgentSnapshot(fields: fields) else {
        Logger.warn("network agent returned incomplete field set")
        return
      }
      publish(snapshot: snapshot)

    case .pong:
      break

    case .error:
      Logger.warn("network agent error=\(message.message ?? "unknown")")
    }
  }

  /// Publishes one snapshot to the shared store on the main queue.
  private func publish(snapshot: NetworkAgentSnapshot) {
    DispatchQueue.main.async {
      NativeWiFiStore.shared.apply(snapshot: snapshot)
    }
  }
}
