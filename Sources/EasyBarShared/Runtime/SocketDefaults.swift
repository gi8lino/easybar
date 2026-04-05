import Foundation

/// Returns the parent directory of the given Unix socket path.
public func socketDirectoryPath(for socketPath: String) -> String {
  URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
}
