import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {
  private typealias Transport = LineSocketServerTransport<
    IPC.Request,
    IPC.Request,
    IPC.Message
  >

  private var transport = SocketServer.makeTransport(
    socketPath: SharedRuntimeConfig.current.easyBarSocketPath
  )
  private var socketPath = SharedRuntimeConfig.current.easyBarSocketPath
  private var commandHandler: ((IPC.Command) -> Void)?

  /// Starts the socket listener.
  func start(handler: @escaping (IPC.Command) -> Void) {
    commandHandler = handler
    transport.start { clientFD, request in
      self.handle(clientFD: clientFD, request: request, handler: handler)
    }
  }

  /// Reloads the socket server when the configured socket path changed.
  func reloadConfiguration() {
    let updatedSocketPath = SharedRuntimeConfig.current.easyBarSocketPath
    guard updatedSocketPath != socketPath else { return }
    guard let commandHandler else {
      socketPath = updatedSocketPath
      transport = Self.makeTransport(socketPath: updatedSocketPath)
      return
    }

    easybarLog.info(
      "restarting socket server old_path=\(socketPath) new_path=\(updatedSocketPath)"
    )

    MetricsCoordinator.shared.resetStreaming()
    transport.stop()
    socketPath = updatedSocketPath
    transport = Self.makeTransport(socketPath: updatedSocketPath)
    transport.start { clientFD, request in
      self.handle(clientFD: clientFD, request: request, handler: commandHandler)
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
    handler: @escaping (IPC.Command) -> Void
  ) -> Transport.ClientDisposition {
    easybarLog.debug("socket dispatching command '\(request.command.rawValue)'")

    if request.command == .metrics {
      let snapshot = MetricsCoordinator.shared.snapshot()
      let sent = self.transport.send(
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

      self.transport.addSubscriber(request, for: clientFD)
      MetricsCoordinator.shared.addStreamingSubscriber(fd: clientFD)
      return .keepOpen
    }

    _ = self.transport.send(.accepted, to: clientFD)

    handler(request.command)

    return .close
  }

  /// Creates one transport bound to the given socket path.
  private static func makeTransport(socketPath: String) -> Transport {
    Transport(
      socketPath: socketPath,
      serverLabel: "easybar",
      debugLog: easybarLog.debug,
      infoLog: easybarLog.info,
      warnLog: easybarLog.warn,
      errorLog: easybarLog.error
    )
  }
}
