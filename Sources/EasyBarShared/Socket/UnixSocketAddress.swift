import Darwin
import Foundation

/// Errors produced while building Unix-domain socket addresses.
public enum UnixSocketAddressError: Error, CustomStringConvertible, LocalizedError {
  case pathTooLong(path: String, maxBytes: Int)

  /// Printable socket address error.
  public var description: String {
    switch self {
    case .pathTooLong(let path, let maxBytes):
      return "Unix socket path is too long (\(path.utf8.count) bytes, max \(maxBytes)): \(path)"
    }
  }

  /// User-facing socket address error.
  public var errorDescription: String? {
    description
  }
}

/// Builds a Unix domain socket address for the given path.
public func makeSockAddrUn(path: String) throws -> sockaddr_un {
  var addr = sockaddr_un()
  addr.sun_family = sa_family_t(AF_UNIX)

  let bytes = Array(path.utf8)
  let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
  let maxPathBytes = maxLen - 1

  guard bytes.count <= maxPathBytes else {
    throw UnixSocketAddressError.pathTooLong(path: path, maxBytes: maxPathBytes)
  }

  withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
    ptr.withMemoryRebound(to: CChar.self, capacity: maxLen) { cptr in
      memset(cptr, 0, maxLen)

      for (index, byte) in bytes.enumerated() {
        cptr[index] = CChar(bitPattern: byte)
      }
    }
  }

  return addr
}
