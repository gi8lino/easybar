import Foundation

/// Returns the configured log directory used by EasyBar processes.
public func defaultLogDirectoryPath() -> URL {
  if let configuredPath = configuredLoggingDirectoryValue(),
    !configuredPath.isEmpty
  {
    return URL(fileURLWithPath: configuredPath)
  }

  return FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/easybar")
}

/// Returns the default log file path used by the EasyBar app.
public func defaultEasyBarLogPath() -> String {
  defaultLogDirectoryPath()
    .appendingPathComponent("easybar.out")
    .path
}

/// Returns the default log file path used by the calendar agent.
public func defaultCalendarAgentLogPath() -> String {
  defaultLogDirectoryPath()
    .appendingPathComponent("calendar-agent.out")
    .path
}

/// Returns the default log file path used by the network agent.
public func defaultNetworkAgentLogPath() -> String {
  defaultLogDirectoryPath()
    .appendingPathComponent("network-agent.out")
    .path
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

/// Returns the configured logging directory from config.toml.
func configuredLoggingDirectoryValue() -> String? {
  guard let text = sharedConfigFileText() else { return nil }

  var inLoggingSection = false

  for rawLine in text.components(separatedBy: .newlines) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !line.isEmpty, !line.hasPrefix("#") else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      inLoggingSection = (line == "[logging]")
      continue
    }

    guard inLoggingSection, line.hasPrefix("directory") else { continue }
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

/// Returns one boolean logging value from config.toml.
func configuredLoggingBoolValue(key: String) -> Bool? {
  guard let text = sharedConfigFileText() else { return nil }

  var inLoggingSection = false

  for rawLine in text.components(separatedBy: .newlines) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !line.isEmpty, !line.hasPrefix("#") else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      inLoggingSection = (line == "[logging]")
      continue
    }

    guard inLoggingSection, line.hasPrefix(key) else { continue }
    guard let equals = line.firstIndex(of: "=") else { continue }

    let rawValue = line[line.index(after: equals)...]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    let unquoted =
      rawValue
      .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
      .first?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    return sharedParseBool(unquoted)
  }

  return nil
}
