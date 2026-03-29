import Darwin
import EasyBarShared
import Foundation

final class CalendarSocketServer {
  private struct Subscriber {
    let query: CalendarAgentQuery
  }

  private var provider: CalendarSnapshotProvider?
  private let transport: LineSocketServerTransport<Subscriber, CalendarAgentRequest, CalendarAgentMessage>

  /// Builds the calendar socket server for one socket path.
  init(socketPath: String) {
    transport = LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: "calendar agent",
      debugLog: AgentLogger.debug,
      infoLog: AgentLogger.info,
      warnLog: AgentLogger.warn,
      errorLog: AgentLogger.error
    )
  }

  /// Starts accepting calendar agent requests.
  func start(provider: CalendarSnapshotProvider) {
    self.provider = provider
    transport.start { [weak self] clientFD, request in
      self?.handleClient(clientFD, request: request)
    }
  }

  /// Stops the calendar socket server.
  func stop() {
    transport.stop()
  }

  /// Broadcasts fresh snapshots to all subscribers.
  func broadcastSnapshots() {
    guard let provider else { return }

    for subscriber in transport.subscribersSnapshot() {
      let snapshot = provider.snapshot(for: subscriber.subscriber.query)
      let message = CalendarAgentMessage(kind: .snapshot, snapshot: snapshot)

      if !transport.send(message, to: subscriber.fd) {
        _ = transport.removeSubscriber(fd: subscriber.fd)
      }
    }
  }

  /// Handles one calendar agent client request.
  private func handleClient(_ clientFD: Int32, request: CalendarAgentRequest) {
    AgentLogger.debug("calendar agent request fd=\(clientFD) command=\(request.command.rawValue)")

    switch request.command {
    case .ping:
      _ = transport.send(CalendarAgentMessage(kind: .pong), to: clientFD)
      close(clientFD)

    case .fetch:
      guard let provider, let query = request.query else {
        _ = transport.send(CalendarAgentMessage(kind: .error, message: "missing_query"), to: clientFD)
        close(clientFD)
        return
      }

      let snapshot = provider.snapshot(for: query)
      _ = transport.send(CalendarAgentMessage(kind: .snapshot, snapshot: snapshot), to: clientFD)
      close(clientFD)

    case .subscribe:
      guard let provider, let query = request.query else {
        _ = transport.send(CalendarAgentMessage(kind: .error, message: "missing_query"), to: clientFD)
        close(clientFD)
        return
      }

      // Keep the client open so future calendar changes can be pushed.
      transport.addSubscriber(Subscriber(query: query), for: clientFD)
      AgentLogger.info("calendar agent subscriber added fd=\(clientFD)")

      guard transport.send(CalendarAgentMessage(kind: .subscribed), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }

      let snapshot = provider.snapshot(for: query)
      guard transport.send(CalendarAgentMessage(kind: .snapshot, snapshot: snapshot), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }
    }
  }
}
