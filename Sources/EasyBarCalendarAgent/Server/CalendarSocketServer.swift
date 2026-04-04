import Darwin
import EasyBarShared
import Foundation

final class CalendarSocketServer {
  private struct Subscriber {
    let query: CalendarAgentQuery
  }

  private var provider: CalendarSnapshotProvider?
  private let transport:
    LineSocketServerTransport<Subscriber, CalendarAgentRequest, CalendarAgentMessage>

  /// Builds the calendar socket server for one socket path.
  init(socketPath: String) {
    transport = LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: "calendar agent",
      debugLog: calendarAgentLog.debug,
      infoLog: calendarAgentLog.info,
      warnLog: calendarAgentLog.warn,
      errorLog: calendarAgentLog.error
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
    calendarAgentLog.debug("calendar agent request fd=\(clientFD) command=\(request.command.rawValue)")

    switch request.command {
    case .ping:
      _ = transport.send(CalendarAgentMessage(kind: .pong), to: clientFD)
      close(clientFD)

    case .fetch:
      guard let provider, let query = request.query else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_query"),
          to: clientFD
        )
        close(clientFD)
        return
      }

      let snapshot = provider.snapshot(for: query)
      _ = transport.send(
        CalendarAgentMessage(kind: .snapshot, snapshot: snapshot),
        to: clientFD
      )
      close(clientFD)

    case .subscribe:
      guard let provider, let query = request.query else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_query"),
          to: clientFD
        )
        close(clientFD)
        return
      }

      transport.addSubscriber(Subscriber(query: query), for: clientFD)
      calendarAgentLog.info("calendar agent subscriber added fd=\(clientFD)")

      guard transport.send(CalendarAgentMessage(kind: .subscribed), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }

      let snapshot = provider.snapshot(for: query)
      guard
        transport.send(
          CalendarAgentMessage(kind: .snapshot, snapshot: snapshot),
          to: clientFD
        )
      else {
        _ = transport.removeSubscriber(fd: clientFD)
        return
      }

    case .createEvent:
      guard let provider, let createEvent = request.createEvent else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_create_event"),
          to: clientFD
        )
        close(clientFD)
        return
      }

      do {
        _ = try provider.createEvent(createEvent)
        _ = transport.send(CalendarAgentMessage(kind: .created), to: clientFD)
      } catch {
        calendarAgentLog.error("calendar event creation failed error=\(error)")
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "create_event_failed"),
          to: clientFD
        )
      }

      close(clientFD)

    case .updateEvent:
      guard let provider, let updateEvent = request.updateEvent else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_update_event"),
          to: clientFD
        )
        close(clientFD)
        return
      }

      do {
        try provider.updateEvent(updateEvent)
        _ = transport.send(CalendarAgentMessage(kind: .updated), to: clientFD)
      } catch {
        calendarAgentLog.error("calendar event update failed error=\(error)")
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "update_event_failed"),
          to: clientFD
        )
      }

      close(clientFD)

    case .deleteEvent:
      guard let provider, let deleteEvent = request.deleteEvent else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_delete_event"),
          to: clientFD
        )
        close(clientFD)
        return
      }

      do {
        try provider.deleteEvent(deleteEvent)
        _ = transport.send(CalendarAgentMessage(kind: .deleted), to: clientFD)
      } catch {
        calendarAgentLog.error("calendar event delete failed error=\(error)")
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "delete_event_failed"),
          to: clientFD
        )
      }

      close(clientFD)
    }
  }
}
