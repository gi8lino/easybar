import Darwin
import EasyBarShared
import Foundation

/// Streaming client for `--metrics --watch`.
struct MetricsStreamClient {
  /// Unix-domain socket path used for the metrics stream.
  let socketPath: String

  /// Opens a socket, sends the metrics request, and handles streamed messages line by line.
  func stream(
    request: IPC.Request,
    handleMessage: (IPC.Message) throws -> Void
  ) throws {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw LineSocketClientTransportError.socketFailed
    }

    defer { close(fd) }

    guard configureNoSigPipe(fd: fd) else {
      throw LineSocketClientTransportError.connectFailed("failed to configure socket no-sigpipe")
    }

    var addr = try makeSockAddrUn(path: socketPath)
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let connectResult = withUnsafePointer(to: &addr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, addrLen)
      }
    }

    guard connectResult == 0 else {
      throw LineSocketClientTransportError.connectFailed(String(cString: strerror(errno)))
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    guard let payload = try? encoder.encode(request) else {
      throw LineSocketClientTransportError.encodeFailed
    }

    try sendAll(fd: fd, data: payload + Data([0x0A]))

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var pending = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)

    while true {
      // Consume complete lines first so partial reads can accumulate in `pending`.
      if let line = nextLine(from: &pending) {
        let message = try decoder.decode(IPC.Message.self, from: line)
        try handleMessage(message)
        continue
      }

      let count = read(fd, &buffer, buffer.count)

      if count > 0 {
        pending.append(contentsOf: buffer.prefix(count))
        continue
      }

      if count == 0 {
        return
      }

      if errno == EINTR {
        continue
      }

      throw LineSocketClientTransportError.connectFailed(String(cString: strerror(errno)))
    }
  }

  /// Writes the full encoded request payload to the socket.
  private func sendAll(fd: Int32, data: Data) throws {
    try data.withUnsafeBytes { rawBuffer in
      guard let base = rawBuffer.baseAddress else { return }

      var sent = 0
      while sent < data.count {
        let written = write(fd, base.advanced(by: sent), data.count - sent)

        if written <= 0 {
          if errno == EINTR {
            continue
          }

          throw LineSocketClientTransportError.writeFailed(String(cString: strerror(errno)))
        }

        sent += written
      }
    }
  }

  /// Removes and returns the next newline-delimited payload from pending data.
  private func nextLine(from pending: inout Data) -> Data? {
    guard let newlineIndex = pending.firstIndex(of: 0x0A) else {
      return nil
    }

    let line = Data(pending.prefix(upTo: newlineIndex))
    pending.removeSubrange(...newlineIndex)
    return line.isEmpty ? nil : line
  }
}
