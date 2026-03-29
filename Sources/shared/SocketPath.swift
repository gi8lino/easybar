import Foundation

/// Returns the default Unix socket path used by EasyBar.
///
/// EASYBAR_SOCKET_PATH overrides the default when set.
public func defaultSocketPath() -> String {
  if let override = ProcessInfo.processInfo.environment["EASYBAR_SOCKET_PATH"]?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    !override.isEmpty
  {
    return override
  }

  return "/tmp/EasyBar/easybar.sock"
}

/// Returns the parent directory of the given Unix socket path.
public func socketDirectoryPath(for socketPath: String) -> String {
  URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
}
