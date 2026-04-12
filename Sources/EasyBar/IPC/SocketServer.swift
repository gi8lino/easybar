import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {
  private let transport = LineSocketServerTransport<
    IPC.Request,
    IPC.Request,
    IPC.Message
  >(
    socketPath: SharedRuntimeConfig.current.easyBarSocketPath,
    serverLabel: "easybar",
    debugLog: easybarLog.debug,
    infoLog: easybarLog.info,
    warnLog: easybarLog.warn,
    errorLog: easybarLog.error
  )

  /// Starts the socket listener.
  func start(handler: @escaping (IPC.Command) -> Void) {
    transport.start { clientFD, request in
      easybarLog.debug("socket dispatching command '\(request.command.rawValue)'")

      if request.command == .metrics {
        let snapshot = MetricsCoordinator.shared.snapshot()
        let sent = self.transport.send(
          IPC.Message(kind: .metrics, metrics: snapshot),
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

      _ = self.transport.send(IPC.Message(kind: .accepted), to: clientFD)

      DispatchQueue.main.async {
        handler(request.command)
      }

      return .close
    }
  }

  /// Stops the socket listener.
  func stop() {
    MetricsCoordinator.shared.resetStreaming()
    transport.stop()
  }

  /// Broadcasts one metrics payload to all active stream subscribers.
  func broadcastMetrics(_ snapshot: IPC.MetricsSnapshot) {
    let message = IPC.Message(kind: .metrics, metrics: snapshot)

    for subscriber in transport.subscribersSnapshot() {
      if !transport.send(message, to: subscriber.fd) {
        _ = transport.removeSubscriber(fd: subscriber.fd)
        MetricsCoordinator.shared.removeStreamingSubscriber(fd: subscriber.fd)
      }
    }
  }
}
