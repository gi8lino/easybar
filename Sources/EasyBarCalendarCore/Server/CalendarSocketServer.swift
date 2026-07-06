import Darwin
import EasyBarShared
import Foundation

/// Serves calendar agent requests over a line-delimited socket protocol.
@MainActor
final class CalendarSocketServer {
  /// Active subscription state for one connected client.
  private struct Subscriber {
    /// Query used when broadcasting snapshots to this subscriber.
    let query: CalendarAgentQuery
  }

  /// Disposition returned after handling one client request.
  private typealias ClientDisposition = LineSocketServerTransport<
    Subscriber,
    CalendarAgentRequest,
    CalendarAgentMessage
  >.ClientDisposition

  /// Snapshot provider used to answer requests.
  private var provider: CalendarSnapshotProvider?
  /// EasyBar app version reported to clients.
  private let appVersion: String
  /// Logger used for socket-server diagnostics.
  private let logger: ProcessLogger
  /// Line-delimited socket transport backing the server.
  private let transport: LineSocketServerTransport<Subscriber, CalendarAgentRequest, CalendarAgentMessage>

  /// Builds the calendar socket server for one socket path.
  init(
    socketPath: String,
    appVersion: String,
    logger: ProcessLogger
  ) {
    self.appVersion = appVersion
    self.logger = logger
    transport = LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: "calendar agent",
      logger: logger.child("transport"),
    )
  }

  /// Starts accepting calendar agent requests.
  func start(provider: CalendarSnapshotProvider) {
    self.provider = provider
    transport.start { [weak self] clientFD, request in
      guard let self else { return .close }
      return self.handleClient(clientFD, request: request)
    }
  }

  /// Stops the calendar socket server.
  func stop() {
    transport.stop()
  }

  /// Broadcasts fresh snapshots to all subscribers.
  func broadcastSnapshots() {
    guard let provider else { return }

    transport.broadcast { subscriber in
      CalendarAgentMessage(
        kind: .snapshot,
        snapshot: provider.snapshot(for: subscriber.query)
      )
    }
  }

  /// Handles one calendar agent client request.
  private func handleClient(
    _ clientFD: Int32,
    request: CalendarAgentRequest
  ) -> ClientDisposition {
    logger.debug(
      "calendar agent request",
      .field("fd", clientFD),
      .field("command", request.command.rawValue),
    )

    switch request.command {
    case .version:
      return sendVersion(to: clientFD)
    case .ping:
      return sendPong(to: clientFD)
    case .fetch:
      return handleFetch(to: clientFD, request: request)
    case .subscribe:
      return handleSubscribe(to: clientFD, request: request)
    case .createEvent:
      return handleCreateEvent(to: clientFD, request: request)
    case .updateEvent:
      return handleUpdateEvent(to: clientFD, request: request)
    case .deleteEvent:
      return handleDeleteEvent(to: clientFD, request: request)
    }
  }

  /// Sends the calendar-agent version response.
  private func sendVersion(to clientFD: Int32) -> ClientDisposition {
    _ = transport.send(
      CalendarAgentMessage(
        kind: .version,
        version: CalendarAgentVersion(
          appVersion: appVersion,
          protocolVersion: easyBarIPCProtocolVersion
        )
      ),
      to: clientFD
    )
    return .close
  }

  /// Sends a pong response.
  private func sendPong(to clientFD: Int32) -> ClientDisposition {
    _ = transport.send(CalendarAgentMessage(kind: .pong), to: clientFD)
    return .close
  }

  /// Handles a one-shot snapshot fetch.
  private func handleFetch(
    to clientFD: Int32,
    request: CalendarAgentRequest
  ) -> ClientDisposition {
    guard let provider, let query = request.query else {
      return sendError(
        to: clientFD,
        code: .missingQuery,
        message: "Missing calendar query."
      )
    }

    let snapshot = provider.snapshot(for: query)
    _ = transport.send(
      CalendarAgentMessage(kind: .snapshot, snapshot: snapshot),
      to: clientFD
    )
    return .close
  }

  /// Handles a live snapshot subscription.
  private func handleSubscribe(
    to clientFD: Int32,
    request: CalendarAgentRequest
  ) -> ClientDisposition {
    guard let provider, let query = request.query else {
      return sendError(
        to: clientFD,
        code: .missingQuery,
        message: "Missing calendar query."
      )
    }

    transport.addSubscriber(Subscriber(query: query), for: clientFD)
    logger.info(
      "calendar agent subscriber added",
      .field("fd", clientFD),
    )

    guard transport.send(CalendarAgentMessage(kind: .subscribed), to: clientFD) else {
      _ = transport.removeSubscriber(fd: clientFD)
      return .close
    }

    let snapshot = provider.snapshot(for: query)
    guard
      transport.send(
        CalendarAgentMessage(kind: .snapshot, snapshot: snapshot),
        to: clientFD
      )
    else {
      _ = transport.removeSubscriber(fd: clientFD)
      return .close
    }

    return .keepOpen
  }

  /// Handles event creation.
  private func handleCreateEvent(
    to clientFD: Int32,
    request: CalendarAgentRequest
  ) -> ClientDisposition {
    guard let createEvent = request.createEvent else {
      return sendError(
        to: clientFD,
        code: .missingCreateEvent,
        message: "Missing create-event payload."
      )
    }

    return handleMutation(
      to: clientFD,
      successKind: .created,
      failureLogMessage: "calendar event creation failed"
    ) { provider in
      _ = try provider.createEvent(createEvent)
    }
  }

  /// Handles event updates.
  private func handleUpdateEvent(
    to clientFD: Int32,
    request: CalendarAgentRequest
  ) -> ClientDisposition {
    guard let updateEvent = request.updateEvent else {
      return sendError(
        to: clientFD,
        code: .missingUpdateEvent,
        message: "Missing update-event payload."
      )
    }

    return handleMutation(
      to: clientFD,
      successKind: .updated,
      failureLogMessage: "calendar event update failed"
    ) { provider in
      try provider.updateEvent(updateEvent)
    }
  }

  /// Handles event deletion.
  private func handleDeleteEvent(
    to clientFD: Int32,
    request: CalendarAgentRequest
  ) -> ClientDisposition {
    guard let deleteEvent = request.deleteEvent else {
      return sendError(
        to: clientFD,
        code: .missingDeleteEvent,
        message: "Missing delete-event payload."
      )
    }

    return handleMutation(
      to: clientFD,
      successKind: .deleted,
      failureLogMessage: "calendar event delete failed"
    ) { provider in
      try provider.deleteEvent(deleteEvent)
    }
  }

  /// Runs one calendar mutation and sends either its success kind or a structured error.
  private func handleMutation(
    to clientFD: Int32,
    successKind: CalendarAgentMessageKind,
    failureLogMessage: String,
    action: (CalendarSnapshotProvider) throws -> Void
  ) -> ClientDisposition {
    guard let provider else {
      return sendError(
        to: clientFD,
        code: .unknown,
        message: "Calendar provider is unavailable."
      )
    }

    do {
      try action(provider)
      _ = transport.send(CalendarAgentMessage(kind: successKind), to: clientFD)
    } catch {
      sendMutationError(error, to: clientFD, logMessage: failureLogMessage)
    }

    return .close
  }

  /// Sends a structured error response.
  private func sendError(
    to clientFD: Int32,
    code: CalendarAgentErrorCode,
    message: String
  ) -> ClientDisposition {
    _ = transport.send(
      CalendarAgentMessage(
        kind: .error,
        errorCode: code,
        message: message
      ),
      to: clientFD
    )
    return .close
  }

  /// Logs and sends one calendar mutation failure.
  private func sendMutationError(
    _ error: Error,
    to clientFD: Int32,
    logMessage: String
  ) {
    let code = errorCode(for: error, fallback: .unknown)
    logger.error(
      logMessage,
      .field("error", error),
      .field("code", code.rawValue),
    )
    _ = transport.send(
      CalendarAgentMessage(
        kind: .error,
        errorCode: code,
        message: errorMessage(for: error, code: code)
      ),
      to: clientFD
    )
  }

  /// Maps one calendar-domain error to a stable wire-level error code.
  private func errorCode(
    for error: Error,
    fallback: CalendarAgentErrorCode
  ) -> CalendarAgentErrorCode {
    if let createError = error as? CalendarAgentCreateError {
      switch createError {
      case .accessDenied:
        return .accessDenied
      case .invalidDateRange:
        return .invalidDateRange
      case .noWritableCalendar:
        return .noWritableCalendar
      }
    }

    if let mutationError = error as? CalendarAgentMutationError {
      switch mutationError {
      case .eventNotFound:
        return .eventNotFound
      }
    }

    return fallback
  }

  /// Builds one readable wire-level error message from a calendar-domain error.
  private func errorMessage(for error: Error, code: CalendarAgentErrorCode) -> String {
    if let localizedError = error as? LocalizedError,
      let description = localizedError.errorDescription,
      !description.isEmpty
    {
      return description
    }

    let nsError = error as NSError
    let description = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)

    if !description.isEmpty,
      description.caseInsensitiveCompare("The operation couldn’t be completed.") != .orderedSame
    {
      return "\(description) [\(nsError.domain) \(nsError.code)]"
    }

    return "\(code.rawValue) [\(nsError.domain) \(nsError.code)]"
  }
}
