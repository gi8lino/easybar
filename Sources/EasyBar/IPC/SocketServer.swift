import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {
  private let transport = LineSocketServerTransport<
    Void,
    IPC.Request,
    IPC.Response
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

      _ = self.transport.send(IPC.Response(status: .accepted), to: clientFD)

      DispatchQueue.main.async {
        handler(request.command)
      }

      return .close
    }
  }

  /// Stops the socket listener.
  func stop() {
    transport.stop()
  }
}
