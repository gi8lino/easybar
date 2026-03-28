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

  if let configured = configuredCalendarAgentSocketPath(),
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

/// Returns the configured refresh interval for the network agent in seconds.
public func defaultNetworkAgentRefreshIntervalSeconds() -> TimeInterval {
  if let override = ProcessInfo.processInfo.environment[
    "EASYBAR_NETWORK_AGENT_REFRESH_INTERVAL_SECONDS"]?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    let value = TimeInterval(override),
    value >= 0
  {
    return value
  }

  if let configured = configuredAgentIntValue(section: "network", key: "refresh_interval_seconds"),
    configured >= 0
  {
    return TimeInterval(configured)
  }

  return 60
}

/// Returns whether debug logging is enabled for EasyBar processes.
///
/// EASYBAR_DEBUG overrides config when set.
public func defaultDebugLoggingEnabled() -> Bool {
  if let override = ProcessInfo.processInfo.environment["EASYBAR_DEBUG"]?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    let value = sharedParseBool(override)
  {
    return value
  }

  return configuredLoggingBoolValue(key: "debug") ?? false
}

/// Returns whether file logging is enabled for EasyBar processes.
public func defaultFileLoggingEnabled() -> Bool {
  configuredLoggingBoolValue(key: "enabled") ?? false
}

/// Returns the parent directory of the given Unix socket path.
public func socketDirectoryPath(for socketPath: String) -> String {
  URL(fileURLWithPath: socketPath).deletingLastPathComponent().path
}

private func configuredCalendarAgentSocketPath() -> String? {
  configuredAgentSocketPath(section: "calendar")
}

private func configuredAgentSocketPath(section: String) -> String? {
  guard let text = sharedConfigFileText() else { return nil }

  var inAgentSection = false

  for rawLine in text.components(separatedBy: .newlines) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !line.isEmpty, !line.hasPrefix("#") else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      inAgentSection = (line == "[agents.\(section)]")
      continue
    }

    guard inAgentSection,
      line.hasPrefix("socket_path")
    else {
      continue
    }

    guard let equals = line.firstIndex(of: "=") else { continue }

    let rawValue = line[line.index(after: equals)...]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let unquoted =
      rawValue
      .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard unquoted.hasPrefix("\""), unquoted.hasSuffix("\""), unquoted.count >= 2 else {
      continue
    }

    let start = unquoted.index(after: unquoted.startIndex)
    let end = unquoted.index(before: unquoted.endIndex)
    return NSString(string: String(unquoted[start..<end])).expandingTildeInPath
  }

  return nil
}

private func configuredAgentIntValue(section: String, key: String) -> Int? {
  guard let text = sharedConfigFileText() else { return nil }

  var inAgentSection = false

  for rawLine in text.components(separatedBy: .newlines) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !line.isEmpty, !line.hasPrefix("#") else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      inAgentSection = (line == "[agents.\(section)]")
      continue
    }

    guard inAgentSection,
      line.hasPrefix(key)
    else {
      continue
    }

    guard let equals = line.firstIndex(of: "=") else { continue }

    let rawValue = line[line.index(after: equals)...]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let unquoted =
      rawValue
      .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    return Int(unquoted)
  }

  return nil
}
