import EasyBarShared
import Foundation

final class NetworkAgentClient {
  static let shared = NetworkAgentClient()

  private let permissionDeniedReconnectDelay: TimeInterval = 60

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
    },
    debugLog: Logger.debug,
    infoLog: Logger.info,
    warnLog: Logger.warn,
    errorLog: Logger.error
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
      Logger.info("network agent client subscribed")

    case .fields:
      client.setNextReconnectDelay(nil)

      guard let fields = message.fields else { return }
      guard let snapshot = NetworkAgentSnapshot(fields: fields) else {
        Logger.warn("network agent returned incomplete field set")
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
    Logger.warn("network agent error=\(message)")

    guard message.hasPrefix("permission_denied") else { return }
    client.setNextReconnectDelay(permissionDeniedReconnectDelay)

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
