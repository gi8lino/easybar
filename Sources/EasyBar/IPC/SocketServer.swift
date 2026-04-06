import EasyBarShared
import Foundation

/// Unix socket server used to receive external triggers.
final class SocketServer {

  private let socketPath = defaultEasyBarSocketPath()
  private var listenFD: Int32 = -1
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  /// Starts the socket listener.
  func start(handler: @escaping (IPC.Command) -> Void) {
    guard prepareSocketDirectory() else { return }
    guard let listenFD = makeListeningSocket() else { return }

    self.listenFD = listenFD

    easybarLog.info("socket listening on \(socketPath)")

    DispatchQueue.global(qos: .userInitiated).async {
      self.acceptLoop(handler: handler)
    }
  }

  /// Accepts incoming socket clients.
  private func acceptLoop(handler: @escaping (IPC.Command) -> Void) {
    while true {
      guard let client = acceptClient() else { continue }

      easybarLog.debug("socket accepted client")
      handleClient(client, handler: handler)
    }
  }

  /// Creates the socket directory when needed.
  private func prepareSocketDirectory() -> Bool {
    let socketDirectory = socketDirectoryPath(for: socketPath)

    do {
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: socketDirectory, isDirectory: true),
        withIntermediateDirectories: true
      )
      return true
    } catch {
      easybarLog.error("failed to create socket directory at \(socketDirectory): \(error)")
      return false
    }
  }

  /// Creates, binds, and starts listening on the IPC socket.
  private func makeListeningSocket() -> Int32? {
    unlink(socketPath)

    let listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
    guard listenFD >= 0 else {
      easybarLog.error("failed to create socket")
      return nil
    }

    guard bindSocket(listenFD) else {
      close(listenFD)
      return nil
    }

    guard listen(listenFD, 5) >= 0 else {
      easybarLog.error("failed to listen on socket at \(socketPath)")
      close(listenFD)
      return nil
    }

    return listenFD
  }

  /// Binds one socket FD to the configured path.
  private func bindSocket(_ listenFD: Int32) -> Bool {
    var addr = makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(listenFD, $0, addrLen)
      }
    }

    guard bindResult >= 0 else {
      easybarLog.error("failed to bind socket at \(socketPath)")
      return false
    }

    return true
  }

  /// Accepts one connected client.
  private func acceptClient() -> Int32? {
    let client = accept(listenFD, nil, nil)
    guard client >= 0 else { return nil }

    var noSigPipe: Int32 = 1
    setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
    return client
  }

  /// Handles one connected IPC client.
  private func handleClient(_ client: Int32, handler: @escaping (IPC.Command) -> Void) {
    defer { close(client) }

    guard let request = readRequest(from: client) else {
      easybarLog.warn("invalid IPC request")
      writeResponse(IPC.Response(status: .rejected, message: "invalid_request"), to: client)
      return
    }

    easybarLog.debug("socket dispatching command '\(request.command.rawValue)'")
    writeResponse(IPC.Response(status: .accepted), to: client)
    DispatchQueue.main.async {
      handler(request.command)
    }
  }

  /// Reads and decodes one IPC request from a client.
  private func readRequest(from client: Int32) -> IPC.Request? {
    var buffer = [UInt8](repeating: 0, count: 256)
    let count = read(client, &buffer, 255)

    guard count >= 0 else {
      easybarLog.warn("socket failed to read request")
      return nil
    }

    let rawBytes = Array(buffer.prefix(count))
    let rawRequest = String(bytes: rawBytes, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)

    easybarLog.debug("socket received raw request '\(rawRequest ?? "unknown")'")

    guard let rawRequest, !rawRequest.isEmpty else {
      easybarLog.warn("socket received empty or non-utf8 request")
      return nil
    }

    guard let data = rawRequest.data(using: .utf8) else {
      easybarLog.warn("socket failed to convert request to utf8 data raw='\(rawRequest)'")
      return nil
    }

    do {
      return try decoder.decode(IPC.Request.self, from: data)
    } catch {
      easybarLog.warn("socket invalid IPC request raw='\(rawRequest)' error=\(error)")
      return nil
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

/// Returns the default Unix socket path used by EasyBar.
private func defaultEasyBarSocketPath() -> String {
  if let override = ProcessInfo.processInfo.environment["EASYBAR_SOCKET_PATH"]?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    !override.isEmpty
  {
    return override
  }

  return "/tmp/EasyBar/easybar.sock"
}
