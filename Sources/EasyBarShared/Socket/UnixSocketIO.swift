import Darwin
import Foundation

/// Configures one Unix socket file descriptor to suppress SIGPIPE on write.
@discardableResult
public func configureNoSigPipe(fd: Int32) -> Bool {
  var value: Int32 = 1
  return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &value, socklen_t(MemoryLayout<Int32>.size)) == 0
}

/// Writes the full data payload to one connected Unix socket.
public func writeAll(_ data: Data, to fd: Int32) -> Bool {
  data.withUnsafeBytes { rawBuffer in
    guard let base = rawBuffer.baseAddress else { return false }

    var sent = 0
    while sent < data.count {
      let written = write(fd, base.advanced(by: sent), data.count - sent)

      if written <= 0 {
        if errno == EINTR {
          continue
        }

        return false
      }

      sent += written
    }

    return true
  }
}
