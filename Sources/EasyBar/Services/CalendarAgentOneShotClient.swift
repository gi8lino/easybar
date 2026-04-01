import Darwin
import EasyBarShared
import Foundation

/// Sends one newline-delimited request to the calendar agent and reads one response.
enum CalendarAgentOneShotClient {
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
  static func send(
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
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)

    let maxLength = MemoryLayout.size(ofValue: address.sun_path)
    let utf8 = Array(path.utf8)

    guard utf8.count < maxLength else {
      return false
    }

    withUnsafeMutablePointer(to: &address.sun_path) { pointer in
      let raw = UnsafeMutableRawPointer(pointer).assumingMemoryBound(to: UInt8.self)
      raw.initialize(repeating: 0, count: maxLength)

      for (index, byte) in utf8.enumerated() {
        raw[index] = byte
      }
    }

    let length = socklen_t(MemoryLayout<sa_family_t>.size + utf8.count + 1)

    return withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
        Darwin.connect(fd, sockaddrPointer, length) == 0
      }
    }
  }
}

enum CalendarAgentOneShotError: Error {
  case socketCreationFailed
  case connectionFailed
  case writeFailed
  case readFailed
  case emptyResponse
}
