import Darwin
import Foundation

/// Sends one newline-delimited request to the calendar agent and reads one response.
public enum CalendarAgentOneShotClient {
  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  /// Sends one request and returns the first decoded response.
  public static func send(
    request: CalendarAgentRequest,
    socketPath: String
  ) throws -> CalendarAgentMessage {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else {
      throw CalendarAgentOneShotError.socketCreationFailed
    }

    defer {
      shutdown(fd, SHUT_RDWR)
      close(fd)
    }

    guard configureNoSigPipe(fd: fd) else {
      throw CalendarAgentOneShotError.connectionFailed
    }

    guard connectSocket(fd: fd, path: socketPath) else {
      throw CalendarAgentOneShotError.connectionFailed
    }

    let encoded = try encoder.encode(request) + Data("\n".utf8)
    guard writeAll(encoded, to: fd) else {
      throw CalendarAgentOneShotError.writeFailed
    }

    var buffer = Data()
    var chunk = [UInt8](repeating: 0, count: 4096)

    while true {
      let count = read(fd, &chunk, chunk.count)

      if count > 0 {
        buffer.append(contentsOf: chunk.prefix(count))

        if let newlineIndex = buffer.firstIndex(of: 0x0A) {
          let line = buffer.prefix(upTo: newlineIndex)
          return try decoder.decode(CalendarAgentMessage.self, from: Data(line))
        }

        continue
      }

      if count == 0 {
        break
      }

      if errno == EINTR {
        continue
      }

      throw CalendarAgentOneShotError.readFailed
    }

    throw CalendarAgentOneShotError.emptyResponse
  }

  /// Connects one Unix-domain socket to the given filesystem path.
  private static func connectSocket(fd: Int32, path: String) -> Bool {
    var address = makeSockAddrUn(path: path)
    let length = socklen_t(MemoryLayout<sockaddr_un>.size)

    return withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        Darwin.connect(fd, sockaddrPointer, length) == 0
      }
    }
  }
}

/// Errors produced by the one-shot calendar agent client.
public enum CalendarAgentOneShotError: LocalizedError {
  case socketCreationFailed
  case connectionFailed
  case writeFailed
  case readFailed
  case emptyResponse

  public var errorDescription: String? {
    switch self {
    case .socketCreationFailed:
      return "Failed to create the calendar agent socket."
    case .connectionFailed:
      return "Failed to connect to the calendar agent."
    case .writeFailed:
      return "Failed to send the request to the calendar agent."
    case .readFailed:
      return "Failed to read the calendar agent response."
    case .emptyResponse:
      return "The calendar agent returned an empty response."
    }
  }
}
