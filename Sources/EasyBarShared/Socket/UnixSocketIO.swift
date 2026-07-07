import Darwin
import Foundation

private let socketWriteRetryTimeoutMilliseconds: Int32 = 1_000

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
