import Foundation

/// Returns the default log directory used by EasyBar processes.
public func defaultLoggingDirectoryPath() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/easybar")
    .path
}
