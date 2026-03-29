import Darwin
import EasyBarShared
import Foundation

final class NetworkSocketServer {
  private var provider: NetworkSnapshotProvider?
  private let transport: LineSocketServerTransport<Int32, NetworkAgentRequest, NetworkAgentMessage>

  /// Builds the network socket server for one socket path.
  init(socketPath: String) {
    transport = LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: "network agent",
      debugLog: AgentLogger.debug,
      infoLog: AgentLogger.info,
      warnLog: AgentLogger.warn,
      errorLog: AgentLogger.error
    )
  }

  /// Starts accepting network agent requests.
  func start(provider: NetworkSnapshotProvider) {
    self.provider = provider
    transport.start { [weak self] clientFD, request in
      self?.handleClient(clientFD, request: request)
    }
  }

  /// Stops the network socket server.
  func stop() {
    transport.stop()
  }

  /// Broadcasts the latest network snapshot to all subscribers.
  func broadcastSnapshots() {
    guard let provider else { return }

    let snapshot = provider.snapshot()

    for subscriber in transport.subscribersSnapshot() {
      let message = NetworkAgentMessage(kind: .snapshot, snapshot: snapshot)

      if !transport.send(message, to: subscriber.fd) {
        _ = transport.removeSubscriber(fd: subscriber.fd)
      }
    }
  }

  /// Handles one network agent client request.
  private func handleClient(_ clientFD: Int32, request: NetworkAgentRequest) {
    AgentLogger.debug("network agent request fd=\(clientFD) command=\(request.command.rawValue)")

    switch request.command {
    case .ping:
      _ = transport.send(NetworkAgentMessage(kind: .pong), to: clientFD)
      close(clientFD)

    case .fetch:
      guard let provider else {
        _ = transport.send(NetworkAgentMessage(kind: .error, message: "provider_unavailable"), to: clientFD)
        close(clientFD)
        return
      }

      let snapshot = provider.snapshot()
      _ = transport.send(NetworkAgentMessage(kind: .snapshot, snapshot: snapshot), to: clientFD)
      close(clientFD)

    case .subscribe:
      guard let provider else {
        _ = transport.send(NetworkAgentMessage(kind: .error, message: "provider_unavailable"), to: clientFD)
        close(clientFD)
        return
      }

      // Keep the client open so future network changes can be pushed.
      transport.addSubscriber(clientFD, for: clientFD)
      AgentLogger.info("network agent subscriber added fd=\(clientFD)")

      guard transport.send(NetworkAgentMessage(kind: .subscribed), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }

      let snapshot = provider.snapshot()
      guard transport.send(NetworkAgentMessage(kind: .snapshot, snapshot: snapshot), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }
    }
  }
}
