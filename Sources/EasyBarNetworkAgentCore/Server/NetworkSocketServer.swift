import Darwin
import EasyBarShared
import Foundation

/// Serves network-agent socket requests.
@MainActor
final class NetworkSocketServer {
  /// One subscribed client field selection.
  private struct Subscriber {
    /// Fields requested by the subscriber.
    let fields: [NetworkAgentField]
  }

  /// Disposition returned after handling one client request.
  private typealias ClientDisposition = LineSocketServerTransport<
    Subscriber,
    NetworkAgentRequest,
    NetworkAgentMessage
  >.ClientDisposition

  private var provider: NetworkSnapshotProvider?
  private let componentName: String
  private let socketPath: String
  private let appVersion: String
  private let allowUnauthorizedNonSensitiveFields: Bool
  private let logger: ProcessLogger
  private let transport: LineSocketServerTransport<Subscriber, NetworkAgentRequest, NetworkAgentMessage>

  /// Builds the network socket server for one socket path.
  init(
    componentName: String,
    socketPath: String,
    appVersion: String,
    allowUnauthorizedNonSensitiveFields: Bool,
    logger: ProcessLogger
  ) {
    self.componentName = componentName
    self.socketPath = socketPath
    self.appVersion = appVersion
    self.allowUnauthorizedNonSensitiveFields = allowUnauthorizedNonSensitiveFields
    self.logger = logger
    transport = LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: componentName,
      logger: logger.child("transport"),
    )
  }

  /// Starts accepting network agent requests.
  func start(provider: NetworkSnapshotProvider) {
    self.provider = provider
    transport.start { [weak self] clientFD, request in
      SynchronousTask.runOnMainActor { [weak self] in
        guard let self else { return .close }
        return self.handleClient(clientFD, request: request)
      }
    }
  }

  /// Stops the network socket server.
  func stop() {
    transport.stop()
  }

  /// Broadcasts the latest requested fields to all subscribers.
  func broadcastSnapshots() {
    guard let provider else { return }

    transport.broadcast { subscriber in
      makeResponseMessage(from: responseFields(for: subscriber.fields, provider: provider))
    }
  }

  /// Handles one network agent client request.
  private func handleClient(
    _ clientFD: Int32,
    request: NetworkAgentRequest
  ) -> ClientDisposition {
    logger.debug(
      "\(componentName) request",
      .field("fd", clientFD),
      .field("command", request.command.rawValue),
    )

    switch request.command {
    case .ping:
      return sendPong(to: clientFD)
    case .version:
      return sendVersion(to: clientFD)
    case .fetch:
      return handleFetch(to: clientFD, request: request)
    case .subscribe:
      return handleSubscribe(to: clientFD, request: request)
    }
  }

  /// Sends a pong response.
  private func sendPong(to clientFD: Int32) -> ClientDisposition {
    _ = transport.send(NetworkAgentMessage(kind: .pong), to: clientFD)
    return .close
  }

  /// Sends the network-agent version response.
  private func sendVersion(to clientFD: Int32) -> ClientDisposition {
    _ = transport.send(
      NetworkAgentMessage(
        kind: .version,
        version: NetworkAgentVersion(
          appVersion: appVersion,
          protocolVersion: easyBarIPCProtocolVersion
        )
      ),
      to: clientFD
    )
    return .close
  }

  /// Handles a one-shot field fetch.
  private func handleFetch(
    to clientFD: Int32,
    request: NetworkAgentRequest
  ) -> ClientDisposition {
    guard let provider else {
      return sendError(to: clientFD, code: .providerUnavailable)
    }

    guard let fields = validatedFields(from: request) else {
      return sendError(to: clientFD, code: .missingFields)
    }

    let response = responseFields(for: fields, provider: provider)
    _ = transport.send(makeResponseMessage(from: response), to: clientFD)
    return .close
  }

  /// Handles a live field subscription.
  private func handleSubscribe(
    to clientFD: Int32,
    request: NetworkAgentRequest
  ) -> ClientDisposition {
    guard let provider else {
      return sendError(to: clientFD, code: .providerUnavailable)
    }

    guard let fields = validatedFields(from: request) else {
      return sendError(to: clientFD, code: .missingFields)
    }

    transport.addSubscriber(Subscriber(fields: fields), for: clientFD)
    logger.info(
      "\(componentName) subscriber added",
      .field("fd", clientFD),
    )

    guard transport.send(NetworkAgentMessage(kind: .subscribed), to: clientFD) else {
      _ = transport.removeSubscriber(fd: clientFD)
      return .close
    }

    let response = responseFields(for: fields, provider: provider)
    guard transport.send(makeResponseMessage(from: response), to: clientFD) else {
      _ = transport.removeSubscriber(fd: clientFD)
      return .close
    }

    return .keepOpen
  }

  /// Sends a structured network-agent error response.
  private func sendError(
    to clientFD: Int32,
    code: NetworkAgentErrorCode
  ) -> ClientDisposition {
    _ = transport.send(
      NetworkAgentMessage(kind: .error, errorCode: code),
      to: clientFD
    )
    return .close
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
  ) -> (fields: [String: NetworkAgentFieldValue]?, errorCode: NetworkAgentErrorCode?) {
    let response = provider.responseFields(
      for: fields,
      allowUnauthorizedFieldsWithoutLocation: allowUnauthorizedNonSensitiveFields
    )
    return (response.values, response.errorCode)
  }

  /// Builds one network-agent message from a field response result.
  private func makeResponseMessage(
    from response: (fields: [String: NetworkAgentFieldValue]?, errorCode: NetworkAgentErrorCode?)
  ) -> NetworkAgentMessage {
    if let fields = response.fields {
      return NetworkAgentMessage(kind: .fields, fields: fields)
    }

    return NetworkAgentMessage(kind: .error, errorCode: response.errorCode ?? .unknown)
  }
}
