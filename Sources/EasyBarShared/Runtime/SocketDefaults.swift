import Foundation

/// Returns the parent directory of the given Unix socket path.
public func socketDirectoryPath(for socketPath: String) -> String {
  return URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
}
