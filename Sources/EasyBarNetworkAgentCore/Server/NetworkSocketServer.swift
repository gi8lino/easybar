import Darwin
import EasyBarShared
import Foundation

final class NetworkSocketServer {
  private struct Subscriber {
    let fields: [NetworkAgentField]
  }

  private var provider: NetworkSnapshotProvider?
  private let componentName: String
  private let socketPath: String
  private let appVersion: String
  private let allowUnauthorizedNonSensitiveFields: Bool
  private let logger: ProcessLogger
  private let transport:
    LineSocketServerTransport<Subscriber, NetworkAgentRequest, NetworkAgentMessage>

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
      debugLog: logger.debug,
      infoLog: logger.info,
      warnLog: logger.warn,
      errorLog: logger.error
    )
  }

  /// Starts accepting network agent requests.
  func start(provider: NetworkSnapshotProvider) {
    self.provider = provider
    transport.start { [weak self] clientFD, request in
      self?.handleClient(clientFD, request: request) ?? .close
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
      let response = responseFields(for: subscriber.subscriber.fields, provider: provider)
      let message = makeResponseMessage(from: response)

      if !transport.send(message, to: subscriber.fd) {
        _ = transport.removeSubscriber(fd: subscriber.fd)
      }
    }
  }

  /// Handles one network agent client request.
  private func handleClient(
    _ clientFD: Int32,
    request: NetworkAgentRequest
  )
    -> LineSocketServerTransport<Subscriber, NetworkAgentRequest, NetworkAgentMessage>
    .ClientDisposition
  {
    logger.debug(
      """
      \(componentName) request
      fd=\(clientFD)
      command=\(request.command.rawValue)
      """)

    switch request.command {
    case .ping:
      _ = transport.send(NetworkAgentMessage(kind: .pong), to: clientFD)
      return .close

    case .version:
      _ = transport.send(
        NetworkAgentMessage(
          kind: .version,
          version: NetworkAgentVersion(
            appVersion: appVersion,
            protocolVersion: networkAgentProtocolVersion
          )
        ),
        to: clientFD
      )
      return .close

    case .fetch:
      guard let provider else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, errorCode: .providerUnavailable),
          to: clientFD
        )
        return .close
      }

      guard let fields = validatedFields(from: request) else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, errorCode: .missingFields),
          to: clientFD
        )
        return .close
      }

      let response = responseFields(for: fields, provider: provider)
      _ = transport.send(makeResponseMessage(from: response), to: clientFD)
      return .close

    case .subscribe:
      guard let provider else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, errorCode: .providerUnavailable),
          to: clientFD
        )
        return .close
      }

      guard let fields = validatedFields(from: request) else {
        _ = transport.send(
          NetworkAgentMessage(kind: .error, errorCode: .missingFields),
          to: clientFD
        )
        return .close
      }

      transport.addSubscriber(Subscriber(fields: fields), for: clientFD)
      logger.info(
        """
        \(componentName) subscriber added
        fd=\(clientFD)
        """)

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
