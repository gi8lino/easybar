import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {
  private typealias Transport = LineSocketServerTransport<
    IPC.Request,
    IPC.Request,
    IPC.Message
  >

  private let logger: ProcessLogger

  private var transport: Transport
  private var socketPath: String
  private var commandHandler: ((IPC.Command) -> Void)?

  init(
    logger: ProcessLogger,
    socketPath: String = SharedRuntimeConfig.current.easyBarSocketPath
  ) {
    self.logger = logger
    self.socketPath = socketPath
    transport = Self.makeTransport(
      socketPath: socketPath,
      logger: logger.child("transport")
    )
  }

  /// Starts the socket listener.
  func start(handler: @escaping (IPC.Command) -> Void) {
    commandHandler = handler

    let activeTransport = transport

    activeTransport.start { [weak self, weak activeTransport] clientFD, request in
      guard let self, let activeTransport else {
        return .close
      }

      return self.handle(
        clientFD: clientFD,
        request: request,
        handler: handler,
        transport: activeTransport
      )
    }
  }

  /// Reloads the socket server when the configured socket path changed.
  func reloadConfiguration(socketPath updatedSocketPath: String) {
    guard updatedSocketPath != socketPath else { return }

    guard let commandHandler else {
      socketPath = updatedSocketPath
      transport = Self.makeTransport(
        socketPath: updatedSocketPath,
        logger: logger.child("transport")
      )
      return
    }

    logger.info(
      "restarting socket server",
      .field("old_path", "\(socketPath)"),
      .field("new_path", "\(updatedSocketPath)")
    )

    MetricsCoordinator.shared.resetStreaming()
    transport.stop()

    socketPath = updatedSocketPath
    transport = Self.makeTransport(
      socketPath: updatedSocketPath,
      logger: logger.child("transport")
    )

    let activeTransport = transport

    activeTransport.start { [weak self, weak activeTransport] clientFD, request in
      guard let self, let activeTransport else {
        return .close
      }

      return self.handle(
        clientFD: clientFD,
        request: request,
        handler: commandHandler,
        transport: activeTransport
      )
    }
  }

  /// Stops the socket listener.
  func stop() {
    commandHandler = nil

    MetricsCoordinator.shared.resetStreaming()
    transport.stop()
  }

  /// Broadcasts one metrics payload to all active stream subscribers.
  func broadcastMetrics(_ snapshot: IPC.MetricsSnapshot) {
    let message = IPC.Message.metrics(snapshot)

    for subscriber in transport.subscribersSnapshot() {
      if !transport.send(message, to: subscriber.fd) {
        _ = transport.removeSubscriber(fd: subscriber.fd)
        MetricsCoordinator.shared.removeStreamingSubscriber(fd: subscriber.fd)
      }
    }
  }

  /// Handles one decoded IPC request.
  private func handle(
    clientFD: Int32,
    request: IPC.Request,
    handler: @escaping (IPC.Command) -> Void,
    transport: Transport
  ) -> Transport.ClientDisposition {
    logger.debug("socket dispatching command '\(request.command.rawValue)'")

    if request.command == .metrics {
      let snapshot = MetricsCoordinator.shared.snapshot()
      let sent = transport.send(
        .metrics(snapshot),
        to: clientFD
      )

      guard sent else {
        MetricsCoordinator.shared.removeStreamingSubscriber(fd: clientFD)
        return .close
      }

      guard request.watch else {
        return .close
      }

      transport.addSubscriber(request, for: clientFD)
      MetricsCoordinator.shared.addStreamingSubscriber(fd: clientFD)

      return .keepOpen
    }

    _ = transport.send(.accepted, to: clientFD)

    handler(request.command)

    return .close
  }

  /// Creates one transport bound to the given socket path.
  private static func makeTransport(
    socketPath: String,
    logger: ProcessLogger
  ) -> Transport {
    Transport(
      socketPath: socketPath,
      serverLabel: "easybar",
      logger: logger
    )
  }
}
