import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {

  private let socketPath = defaultSocketPath()
  private var listenFD: Int32 = -1
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  /// Starts the socket listener.
  func start(handler: @escaping (IPC.Command) -> Void) {
    let socketDirectory = socketDirectoryPath(for: socketPath)

    do {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: socketDirectory, isDirectory: true),
        withIntermediateDirectories: true
      )
    } catch {
      Logger.error("failed to create socket directory at \(socketDirectory): \(error)")
      return
    }

    unlink(socketPath)

    listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard listenFD >= 0 else {
      Logger.error("failed to create socket")
      return
    }

    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(listenFD, $0, addrLen)
      }
    }

    guard bindResult >= 0 else {
      Logger.error("failed to bind socket at \(socketPath)")
      close(listenFD)
      listenFD = -1
      return
    }

    guard listen(listenFD, 5) >= 0 else {
      Logger.error("failed to listen on socket at \(socketPath)")
      close(listenFD)
      listenFD = -1
      return
    }

    Logger.info("socket listening on \(socketPath)")

    DispatchQueue.global(qos: .userInitiated).async {
      self.acceptLoop(handler: handler)
    }
  }

  /// Accepts incoming socket clients.
  private func acceptLoop(handler: @escaping (IPC.Command) -> Void) {
    while true {
      let client = accept(listenFD, nil, nil)
      if client < 0 {
        continue
      }

      Logger.debug("socket accepted client")

      var buffer = [UInt8](repeating: 0, count: 256)
      let count = read(client, &buffer, 255)

      if count < 0 {
        close(client)
        continue
      }

      let rawCommand = String(bytes: buffer.prefix(count), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)

      Logger.debug("socket received raw command '\(rawCommand ?? "unknown")'")

      guard
        let rawCommand,
        let data = rawCommand.data(using: .utf8),
        let request = try? decoder.decode(IPC.Request.self, from: data)
      else {
        Logger.warn("invalid IPC request")
        writeResponse(IPC.Response(accepted: false, message: "invalid_request"), to: client)
        close(client)
        continue
      }

      Logger.debug("socket dispatching command '\(request.command.rawValue)'")
      writeResponse(IPC.Response(accepted: true), to: client)
      DispatchQueue.main.async {
        handler(request.command)
      }
      close(client)
    }
  }

  /// Writes one IPC response to a connected client.
  private func writeResponse(_ response: IPC.Response, to client: Int32) {
    guard let data = try? encoder.encode(response) else { return }

    _ = data.withUnsafeBytes { buffer in
      guard let baseAddress = buffer.baseAddress else { return -1 }
      return write(client, baseAddress, buffer.count)
    }
  }
}
