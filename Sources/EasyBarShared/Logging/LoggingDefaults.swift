import Foundation

/// Shared log file naming helpers used by EasyBar processes.

/// Returns the default log directory used by EasyBar processes.
public func defaultLoggingDirectoryPath() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/easybar")
    .path
}

/// Returns the EasyBar app log path inside one logging directory.
public func easyBarLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("easybar.out")
    .path
}

/// Returns the calendar agent log path inside one logging directory.
public func calendarAgentLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("calendar-agent.out")
    .path
}

/// Returns the network agent log path inside one logging directory.
public func networkAgentLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("network-agent.out")
    .path
}
