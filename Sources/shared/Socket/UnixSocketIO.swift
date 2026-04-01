import Darwin
import Foundation

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
