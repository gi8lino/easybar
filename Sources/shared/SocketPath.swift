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

/// Returns the default Unix socket path used by the calendar agent.
///
/// EASYBAR_CALENDAR_AGENT_SOCKET overrides the default when set.
public func defaultCalendarAgentSocketPath() -> String {
  if let override = ProcessInfo.processInfo.environment["EASYBAR_CALENDAR_AGENT_SOCKET"]?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    !override.isEmpty
  {
    return override
  }

  if let configured = configuredAgentSocketPath(section: "calendar"),
    !configured.isEmpty
  {
    return configured
  }

  return "/tmp/EasyBar/calendar-agent.sock"
}

/// Returns the default Unix socket path used by the network agent.
///
/// EASYBAR_NETWORK_AGENT_SOCKET overrides the default when set.
public func defaultNetworkAgentSocketPath() -> String {
  if let override = ProcessInfo.processInfo.environment["EASYBAR_NETWORK_AGENT_SOCKET"]?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    !override.isEmpty
  {
    return override
  }

  if let configured = configuredAgentSocketPath(section: "network"),
    !configured.isEmpty
  {
    return configured
  }

  return "/tmp/EasyBar/network-agent.sock"
}

/// Returns the parent directory of the given Unix socket path.
public func socketDirectoryPath(for socketPath: String) -> String {
  URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
}
