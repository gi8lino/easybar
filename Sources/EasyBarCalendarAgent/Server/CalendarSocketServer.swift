import EasyBarShared
import Foundation

final class CalendarSocketServer {
  private struct Subscriber {
    let query: CalendarAgentQuery
  }

  private var provider: CalendarSnapshotProvider?
  private let logger: ProcessLogger
  private let transport:
    LineSocketServerTransport<Subscriber, CalendarAgentRequest, CalendarAgentMessage>

  /// Builds the calendar socket server for one socket path.
  init(socketPath: String, logger: ProcessLogger) {
    self.logger = logger
    transport = LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: "calendar agent",
      debugLog: logger.debug,
      infoLog: logger.info,
      warnLog: logger.warn,
      errorLog: logger.error
    )
  }

  /// Starts accepting calendar agent requests.
  func start(provider: CalendarSnapshotProvider) {
    self.provider = provider
    transport.start { [weak self] clientFD, request in
      self?.handleClient(clientFD, request: request) ?? .close
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
  private func handleClient(
    _ clientFD: Int32,
    request: CalendarAgentRequest
  )
    -> LineSocketServerTransport<Subscriber, CalendarAgentRequest, CalendarAgentMessage>
    .ClientDisposition
  {
    logger.debug("calendar agent request fd=\(clientFD) command=\(request.command.rawValue)")

    switch request.command {
    case .version:
      _ = transport.send(
        CalendarAgentMessage(
          kind: .version,
          version: CalendarAgentVersion(
            appVersion: BuildInfo.appVersion,
            protocolVersion: calendarAgentProtocolVersion
          )
        ),
        to: clientFD
      )
      return .close

    case .ping:
      _ = transport.send(CalendarAgentMessage(kind: .pong), to: clientFD)
      return .close

    case .fetch:
      guard let provider, let query = request.query else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_query"),
          to: clientFD
        )
        return .close
      }

      let snapshot = provider.snapshot(for: query)
      _ = transport.send(
        CalendarAgentMessage(kind: .snapshot, snapshot: snapshot),
        to: clientFD
      )
      return .close

    case .subscribe:
      guard let provider, let query = request.query else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_query"),
          to: clientFD
        )
        return .close
      }

      transport.addSubscriber(Subscriber(query: query), for: clientFD)
      logger.info("calendar agent subscriber added fd=\(clientFD)")

      guard transport.send(CalendarAgentMessage(kind: .subscribed), to: clientFD) else {
        _ = transport.removeSubscriber(fd: clientFD)
        return .keepOpen
      }

      let snapshot = provider.snapshot(for: query)
      guard
        transport.send(
          CalendarAgentMessage(kind: .snapshot, snapshot: snapshot),
          to: clientFD
        )
      else {
        _ = transport.removeSubscriber(fd: clientFD)
        return .keepOpen
      }

      return .keepOpen

    case .createEvent:
      guard let provider, let createEvent = request.createEvent else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_create_event"),
          to: clientFD
        )
        return .close
      }

      do {
        _ = try provider.createEvent(createEvent)
        _ = transport.send(CalendarAgentMessage(kind: .created), to: clientFD)
      } catch {
        logger.error("calendar event creation failed error=\(error)")
        _ = transport.send(
          CalendarAgentMessage(
            kind: .error,
            message: errorMessage(for: error, fallback: "create_event_failed")
          ),
          to: clientFD
        )
      }

      return .close

    case .updateEvent:
      guard let provider, let updateEvent = request.updateEvent else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_update_event"),
          to: clientFD
        )
        return .close
      }

      do {
        try provider.updateEvent(updateEvent)
        _ = transport.send(CalendarAgentMessage(kind: .updated), to: clientFD)
      } catch {
        logger.error("calendar event update failed error=\(error)")
        _ = transport.send(
          CalendarAgentMessage(
            kind: .error,
            message: errorMessage(for: error, fallback: "update_event_failed")
          ),
          to: clientFD
        )
      }

      return .close

    case .deleteEvent:
      guard let provider, let deleteEvent = request.deleteEvent else {
        _ = transport.send(
          CalendarAgentMessage(kind: .error, message: "missing_delete_event"),
          to: clientFD
        )
        return .close
      }

      do {
        try provider.deleteEvent(deleteEvent)
        _ = transport.send(CalendarAgentMessage(kind: .deleted), to: clientFD)
      } catch {
        logger.error("calendar event delete failed error=\(error)")
        _ = transport.send(
          CalendarAgentMessage(
            kind: .error,
            message: errorMessage(for: error, fallback: "delete_event_failed")
          ),
          to: clientFD
        )
      }

      return .close
    }
  }

  /// Maps one calendar-domain error to a stable wire-level error code.
  private func errorMessage(for error: Error, fallback: String) -> String {
    if let createError = error as? CalendarAgentCreateError {
      switch createError {
      case .accessDenied:
        return "access_denied"
      case .invalidDateRange:
        return "invalid_date_range"
      case .noWritableCalendar:
        return "no_writable_calendar"
      }
    }

    if let mutationError = error as? CalendarAgentMutationError {
      switch mutationError {
      case .eventNotFound:
        return "event_not_found"
      }
    }

    return fallback
  }
}
