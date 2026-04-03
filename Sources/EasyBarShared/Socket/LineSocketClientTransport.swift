import Darwin
import Foundation

/// Errors produced by the line socket client transport.
public enum LineSocketClientTransportError: Error, CustomStringConvertible {
  case socketFailed
  case connectFailed(String)
  case encodeFailed
  case decodeFailed(String)
  case writeFailed(String)
  case noReply

  public var description: String {
    switch self {
    case .socketFailed:
      return "socket failed"
    case .connectFailed(let message):
      return "connect failed: \(message)"
    case .encodeFailed:
      return "encode failed"
    case .decodeFailed(let message):
      return "decode failed: \(message)"
    case .writeFailed(let message):
      return "write failed: \(message)"
    case .noReply:
      return "no reply"
    }
  }
}

/// Sends one line-delimited JSON request and decodes one JSON response.
public struct LineSocketClientTransport<Request: Encodable, Response: Decodable> {
  public let socketPath: String

  /// Creates a new client transport for the given socket path.
  public init(socketPath: String) {
    self.socketPath = socketPath
  }

  /// Sends one request and returns one decoded response.
  public func send(request: Request) throws -> Response {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw LineSocketClientTransportError.socketFailed
    }

    defer { close(fd) }

    var addr = makeSockAddrUn(path: socketPath)
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

    try sendAll(fd, payload + Data([0x0A]))

    guard let replyData = readOneLine(from: fd), !replyData.isEmpty else {
      throw LineSocketClientTransportError.noReply
    }

    do {
      return try JSONDecoder().decode(Response.self, from: replyData)
    } catch {
      throw LineSocketClientTransportError.decodeFailed("\(error)")
    }
  }

  /// Writes all bytes to the socket.
  private func sendAll(_ fd: Int32, _ data: Data) throws {
    try data.withUnsafeBytes { rawBuffer in
      guard let base = rawBuffer.baseAddress else { return }

      var sent = 0
      while sent < data.count {
        let n = write(fd, base.advanced(by: sent), data.count - sent)
        if n < 0 {
          throw LineSocketClientTransportError.writeFailed(String(cString: strerror(errno)))
        }
        if n == 0 {
          break
        }
        sent += n
      }
    }
  }

  /// Reads bytes until newline or EOF.
  private func readOneLine(from fd: Int32) -> Data? {
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)

    while true {
      let n = read(fd, &buffer, buffer.count)
      if n < 0 { return nil }
      if n == 0 { break }

      if let newlineIndex = buffer[..<n].firstIndex(of: 0x0A) {
        let count = buffer.distance(from: 0, to: newlineIndex)
        data.append(buffer, count: count)
        break
      }

      data.append(buffer, count: n)
    }

    return data
  }
}
