import Darwin
import EasyBarShared
import Foundation

final class NetworkSocketServer {
  private struct Subscriber {
    let fields: [NetworkAgentField]
  }

  private var provider: NetworkSnapshotProvider?
  private let allowUnauthorizedNonSensitiveFields: Bool
  private let transport:
    LineSocketServerTransport<Subscriber, NetworkAgentRequest, NetworkAgentMessage>

  /// Builds the network socket server for one socket path.
  init(socketPath: String, allowUnauthorizedNonSensitiveFields: Bool) {
    self.allowUnauthorizedNonSensitiveFields = allowUnauthorizedNonSensitiveFields
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

  /// Broadcasts the latest requested fields to all subscribers.
  func broadcastSnapshots() {
    guard let provider else { return }

    for subscriber in transport.subscribersSnapshot() {
      guard
        let values = responseFields(for: subscriber.subscriber.fields, provider: provider).fields
      else {
        continue
      }
      let message = NetworkAgentMessage(kind: .fields, fields: values)

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
        _ = transport.send(
          NetworkAgentMessage(kind: .error, message: "provider_unavailable"), to: clientFD)
        close(clientFD)
        return
      }
      guard let fields = validatedFields(from: request) else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, message: "missing_fields"), to: clientFD)
        close(clientFD)
        return
      }

      let response = responseFields(for: fields, provider: provider)
      if let values = response.fields {
        _ = transport.send(NetworkAgentMessage(kind: .fields, fields: values), to: clientFD)
      } else if let message = response.errorMessage {
        _ = transport.send(NetworkAgentMessage(kind: .error, message: message), to: clientFD)
      }
      close(clientFD)

    case .subscribe:
      guard let provider else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, message: "provider_unavailable"), to: clientFD)
        close(clientFD)
        return
      }
      guard let fields = validatedFields(from: request) else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, message: "missing_fields"), to: clientFD)
        close(clientFD)
        return
      }

      // Keep the client open so future network changes can be pushed.
      transport.addSubscriber(Subscriber(fields: fields), for: clientFD)
      AgentLogger.info("network agent subscriber added fd=\(clientFD)")

      guard transport.send(NetworkAgentMessage(kind: .subscribed), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }

      let response = responseFields(for: fields, provider: provider)
      if let values = response.fields {
        guard transport.send(NetworkAgentMessage(kind: .fields, fields: values), to: clientFD)
        else {
          _ = transport.removeSubscriber(fd: clientFD)
          return
        }
      } else if let message = response.errorMessage {
        _ = transport.send(NetworkAgentMessage(kind: .error, message: message), to: clientFD)
        _ = transport.removeSubscriber(fd: clientFD)
      }
    }
  }

  /// Returns the validated field list for one request.
  private func validatedFields(from request: NetworkAgentRequest) -> [NetworkAgentField]? {
    guard let fields = request.fields, !fields.isEmpty else { return nil }
    return fields
  }

  /// Returns one field response or a permission error for the current auth state.
  private func responseFields(
    for fields: [NetworkAgentField],
    provider: NetworkSnapshotProvider
  ) -> (fields: [String: String]?, errorMessage: String?) {
    let response = provider.responseFields(
      for: fields,
      allowUnauthorizedNonSensitiveFields: allowUnauthorizedNonSensitiveFields
    )
    return (response.values, response.errorMessage)
  }
}
