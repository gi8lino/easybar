import Darwin
import Foundation

/// Errors produced by the line socket client transport.
public enum LineSocketClientTransportError: Error, CustomStringConvertible {
  case socketFailed
  case connectFailed(UnixSocketConnectError)
  case encodeFailed
  case decodeFailed(String)
  case writeFailed(String)
  case readFailed(String)
  case connectionTimedOut(TimeInterval)
  case responseTimedOut(TimeInterval)
  case noReply

  /// Returns a printable transport error.
  public var description: String {
    switch self {
    case .socketFailed:
      return "socket failed"
    case .connectFailed(let error):
      return "connect failed: \(error.description)"
    case .encodeFailed:
      return "encode failed"
    case .decodeFailed(let message):
      return "decode failed: \(message)"
    case .writeFailed(let message):
      return "write failed: \(message)"
    case .readFailed(let message):
      return "read failed: \(message)"
    case .connectionTimedOut(let timeout):
      return "connection timed out after \(timeout) seconds"
    case .responseTimedOut(let timeout):
      return "response timed out after \(timeout) seconds"
    case .noReply:
      return "no reply"
    }
  }
}

/// Sends one line-delimited JSON request and decodes one JSON response.
public struct LineSocketClientTransport<Request: Encodable, Response: Decodable> {
  public let socketPath: String
  public let responseTimeout: TimeInterval
  public let maxResponseBytes: Int

  private let makeEncoder: @Sendable () -> JSONEncoder
  private let makeDecoder: @Sendable () -> JSONDecoder

  /// Creates a new client transport for the given socket path.
  public init(
    socketPath: String,
    responseTimeout: TimeInterval = 5,
    maxResponseBytes: Int = LineDelimitedJSONDecoder<Response>.defaultMaxLineBytes,
    makeEncoder: @escaping @Sendable () -> JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      return encoder
    },
    makeDecoder: @escaping @Sendable () -> JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
    }
  ) {
    self.socketPath = socketPath
    self.responseTimeout = max(0.001, responseTimeout)
    self.maxResponseBytes = max(1, maxResponseBytes)
    self.makeEncoder = makeEncoder
    self.makeDecoder = makeDecoder
  }

  /// Sends one request and returns one decoded response.
  public func send(request: Request) throws -> Response {
    let fd = try connectSocket()

    defer { close(fd) }

    let encoder = makeEncoder()

    guard let payload = try? encoder.encode(request) else {
      throw LineSocketClientTransportError.encodeFailed
    }

    guard writeAll(payload + Data([0x0A]), to: fd) else {
      throw LineSocketClientTransportError.writeFailed("socket write failed")
    }

    return try readOneResponse(from: fd)
  }

  private func connectSocket() throws -> Int32 {
    do {
      return try openConnectedUnixSocket(at: socketPath, timeout: responseTimeout)
    } catch let error as UnixSocketConnectError {
      if case .timedOut(let timeout) = error {
        throw LineSocketClientTransportError.connectionTimedOut(timeout)
      }
      if case .createSocket = error {
        throw LineSocketClientTransportError.socketFailed
      }
      throw LineSocketClientTransportError.connectFailed(error)
    } catch {
      throw error
    }
  }

  /// Reads bytes until one response line decodes or EOF is reached.
  private func readOneResponse(from fd: Int32) throws -> Response {
    var lineDecoder = LineDelimitedJSONDecoder<Response>(
      decoder: makeDecoder(),
      maxLineBytes: maxResponseBytes
    )
    var buffer = [UInt8](repeating: 0, count: 1024)

    let deadline = Date().addingTimeInterval(responseTimeout)

    while true {
      try waitForReadable(fd: fd, deadline: deadline)

      let n = read(fd, &buffer, buffer.count)
      if n < 0 {
        if errno == EINTR {
          continue
        }
        throw LineSocketClientTransportError.noReply
      }

      if n == 0 {
        return try decodeOneResult(lineDecoder.flush())
      }

      let results = lineDecoder.append(buffer.prefix(n))
      if !results.isEmpty {
        return try decodeOneResult(results)
      }
    }
  }

  /// Waits until the socket has data to read or the response deadline expires.
  private func waitForReadable(fd: Int32, deadline: Date) throws {
    while true {
      let remaining = deadline.timeIntervalSinceNow
      guard remaining > 0 else {
        throw LineSocketClientTransportError.responseTimedOut(responseTimeout)
      }

      var pollFD = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      let timeoutMilliseconds = Int32(min(Double(Int32.max), ceil(remaining * 1000)))
      let result = poll(&pollFD, 1, timeoutMilliseconds)

      if result > 0 {
        return
      }

      if result == 0 {
        throw LineSocketClientTransportError.responseTimedOut(responseTimeout)
      }

      if errno == EINTR {
        continue
      }

      throw LineSocketClientTransportError.noReply
    }
  }

  /// Returns the first decoded response from a line decoder result list.
  private func decodeOneResult(_ results: [Result<Response, Error>]) throws -> Response {
    guard let result = results.first else {
      throw LineSocketClientTransportError.noReply
    }

    do {
      return try result.get()
    } catch {
      throw LineSocketClientTransportError.decodeFailed("\(error)")
    }
  }
}
