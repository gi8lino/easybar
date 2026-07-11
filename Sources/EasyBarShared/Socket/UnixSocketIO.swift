import Darwin
import Foundation

private let socketWriteRetryTimeoutMilliseconds: Int32 = 1_000

/// Errors produced while opening a Unix-domain client socket.
public enum UnixSocketConnectError: Error, CustomStringConvertible, LocalizedError {
  case createSocket(errnoValue: Int32)
  case configureNoSigPipe
  case invalidAddress(any Error)
  case connect(errnoValue: Int32)
  case timedOut(TimeInterval)

  public var description: String {
    switch self {
    case .createSocket(let errnoValue):
      return "socket creation failed: \(Self.errnoDescription(errnoValue))"
    case .configureNoSigPipe:
      return "failed to configure socket no-sigpipe"
    case .invalidAddress(let error):
      return "invalid Unix socket address: \(error)"
    case .connect(let errnoValue):
      return "socket connection failed: \(Self.errnoDescription(errnoValue))"
    case .timedOut(let timeout):
      return "socket connection timed out after \(timeout) seconds"
    }
  }

  public var errorDescription: String? { description }

  private static func errnoDescription(_ value: Int32) -> String {
    "\(String(cString: strerror(value))) (errno \(value))"
  }
}

/// Creates and connects one Unix-domain client socket.
public func openConnectedUnixSocket(
  at socketPath: String,
  timeout: TimeInterval = 5
) throws -> Int32 {
  let fd = socket(AF_UNIX, SOCK_STREAM, 0)
  guard fd >= 0 else {
    throw UnixSocketConnectError.createSocket(errnoValue: errno)
  }

  do {
    guard configureNoSigPipe(fd: fd) else {
      throw UnixSocketConnectError.configureNoSigPipe
    }

    var address: sockaddr_un
    do {
      address = try makeSockAddrUn(path: socketPath)
    } catch {
      throw UnixSocketConnectError.invalidAddress(error)
    }

    let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
    let originalFlags = fcntl(fd, F_GETFL)
    guard originalFlags >= 0, fcntl(fd, F_SETFL, originalFlags | O_NONBLOCK) == 0 else {
      throw UnixSocketConnectError.connect(errnoValue: errno)
    }

    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.connect(fd, $0, addressLength)
      }
    }
    if result != 0 {
      guard errno == EINPROGRESS else {
        throw UnixSocketConnectError.connect(errnoValue: errno)
      }

      var descriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
      let milliseconds = Int32(min(max(0.001, timeout) * 1_000, Double(Int32.max)))
      let pollResult = poll(&descriptor, 1, milliseconds)
      guard pollResult > 0 else {
        if pollResult == 0 { throw UnixSocketConnectError.timedOut(max(0.001, timeout)) }
        throw UnixSocketConnectError.connect(errnoValue: errno)
      }

      var socketError: Int32 = 0
      var errorLength = socklen_t(MemoryLayout<Int32>.size)
      guard getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &errorLength) == 0 else {
        throw UnixSocketConnectError.connect(errnoValue: errno)
      }
      guard socketError == 0 else {
        throw UnixSocketConnectError.connect(errnoValue: socketError)
      }
    }
    guard fcntl(fd, F_SETFL, originalFlags) == 0 else {
      throw UnixSocketConnectError.connect(errnoValue: errno)
    }
    return fd
  } catch {
    close(fd)
    throw error
  }
}

/// Errors produced while preparing Unix-domain server sockets.
public enum UnixSocketListenError: Error, CustomStringConvertible, LocalizedError {
  case createDirectory(path: String, message: String)
  case createSocket(errnoValue: Int32)
  case configureNoSigPipe(fd: Int32)
  case invalidAddress(path: String, message: String)
  case existingPathIsNotSocket(path: String)
  case bind(path: String, errnoValue: Int32)
  case listen(path: String, errnoValue: Int32)

  /// Printable socket setup error.
  public var description: String {
    switch self {
    case .createDirectory(let path, let message):
      return "failed to create socket directory path=\(path) error=\(message)"
    case .createSocket(let errnoValue):
      return "failed to create socket errno=\(errnoValue)"
    case .configureNoSigPipe(let fd):
      return "failed to configure server socket no-sigpipe fd=\(fd)"
    case .invalidAddress(let path, let message):
      return "invalid socket path path=\(path) error=\(message)"
    case .existingPathIsNotSocket(let path):
      return "socket path already exists and is not a socket path=\(path)"
    case .bind(let path, let errnoValue):
      return "socket bind failed path=\(path) errno=\(errnoValue)"
    case .listen(let path, let errnoValue):
      return "socket listen failed path=\(path) errno=\(errnoValue)"
    }
  }

  /// User-facing socket setup error.
  public var errorDescription: String? {
    description
  }
}

/// Configures one Unix socket file descriptor to suppress SIGPIPE on write.
@discardableResult
public func configureNoSigPipe(fd: Int32) -> Bool {
  var value: Int32 = 1
  return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int32>.size)) == 0
}

/// Writes the full data payload to one connected Unix socket.
public func writeAll(_ data: Data, to fd: Int32) -> Bool {
  guard !data.isEmpty else { return true }

  return data.withUnsafeBytes { rawBuffer in
    guard let base = rawBuffer.baseAddress else { return false }

    var sent = 0
    while sent < data.count {
      let written = write(fd, base.advanced(by: sent), data.count - sent)

      if written > 0 {
        sent += written
        continue
      }

      if written == 0 {
        return false
      }

      let errnoValue = errno
      if errnoValue == EINTR {
        continue
      }

      if isTemporarilyUnavailable(errnoValue), waitForWritable(fd: fd) {
        continue
      }

      return false
    }

    return true
  }
}

/// Creates, binds, chmods, and starts one Unix-domain listening socket.
public func makeListeningUnixSocket(
  at socketPath: String,
  backlog: Int32,
  mode: mode_t = 0o600,
  onChmodFailure: ((Int32) -> Void)? = nil
) throws -> Int32 {
  let socketURL = URL(fileURLWithPath: socketPath)
  let socketDir = socketURL.deletingLastPathComponent()

  do {
    try FileManager.default.createDirectory(
      at: socketDir,
      withIntermediateDirectories: true
    )
  } catch {
    throw UnixSocketListenError.createDirectory(
      path: socketDir.path,
      message: error.localizedDescription
    )
  }

  var existingInfo = stat()
  if lstat(socketPath, &existingInfo) == 0 {
    guard existingInfo.st_mode & S_IFMT == S_IFSOCK else {
      throw UnixSocketListenError.existingPathIsNotSocket(path: socketPath)
    }
    guard unlink(socketPath) == 0 else {
      throw UnixSocketListenError.bind(path: socketPath, errnoValue: errno)
    }
  } else if errno != ENOENT {
    throw UnixSocketListenError.bind(path: socketPath, errnoValue: errno)
  }

  let fd = socket(AF_UNIX, SOCK_STREAM, 0)
  guard fd >= 0 else {
    throw UnixSocketListenError.createSocket(errnoValue: errno)
  }

  var didBind = false
  do {
    guard configureNoSigPipe(fd: fd) else {
      throw UnixSocketListenError.configureNoSigPipe(fd: fd)
    }

    let addr: sockaddr_un
    do {
      addr = try makeSockAddrUn(path: socketPath)
    } catch {
      throw UnixSocketListenError.invalidAddress(path: socketPath, message: "\(error)")
    }

    var mutableAddr = addr
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

    let bindResult = withUnsafePointer(to: &mutableAddr) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(fd, $0, addrLen)
      }
    }

    guard bindResult == 0 else {
      throw UnixSocketListenError.bind(path: socketPath, errnoValue: errno)
    }
    didBind = true

    if chmod(socketPath, mode) != 0 {
      onChmodFailure?(errno)
    }

    guard listen(fd, backlog) == 0 else {
      throw UnixSocketListenError.listen(path: socketPath, errnoValue: errno)
    }

    return fd
  } catch {
    close(fd)
    if didBind {
      unlink(socketPath)
    }
    throw error
  }
}

/// Closes one Unix-domain listening socket and removes its filesystem path.
public func closeListeningUnixSocket(_ fd: Int32, at socketPath: String) {
  Darwin.shutdown(fd, SHUT_RDWR)
  close(fd)
  unlink(socketPath)
}

/// Returns whether one socket write failed because the descriptor would block.
private func isTemporarilyUnavailable(_ errnoValue: Int32) -> Bool {
  errnoValue == EAGAIN || errnoValue == EWOULDBLOCK
}

/// Waits briefly until one socket fd is writable again.
private func waitForWritable(fd: Int32) -> Bool {
  var pollDescriptor = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)

  while true {
    let result = poll(&pollDescriptor, 1, socketWriteRetryTimeoutMilliseconds)

    if result > 0 {
      let revents = Int32(pollDescriptor.revents)
      let hasFailure = (revents & (POLLERR | POLLHUP | POLLNVAL)) != 0
      let isWritable = (revents & POLLOUT) != 0
      return isWritable && !hasFailure
    }

    if result == 0 {
      return false
    }

    if errno == EINTR {
      continue
    }

    return false
  }
}
