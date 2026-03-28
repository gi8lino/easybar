import Foundation

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

/// Returns the shared support directory used by EasyBar for editor-facing assets.
public func defaultSupportDirectoryPath() -> URL {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/share/easybar")
}

/// Returns the default Lua editor stub path installed for widget workspaces.
public func defaultWidgetEditorStubPath() -> URL {
  defaultSupportDirectoryPath()
    .appendingPathComponent("easybar_api.lua")
}

func sharedConfigFileText() -> String? {
  try? String(
    contentsOfFile: sharedResolvedConfigPath(),
    encoding: .utf8
  )
}

func sharedResolvedConfigPath() -> String {
  guard
    let override = ProcessInfo.processInfo.environment["EASYBAR_CONFIG_PATH"]?
      .trimmingCharacters(in: .whitespacesAndNewlines),
    !override.isEmpty
  else {
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/config.toml")
      .path
  }

  return NSString(string: override).expandingTildeInPath
}

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

func sharedParseBool(_ value: String) -> Bool? {
  switch value.lowercased() {
  case "1", "true", "yes", "on":
    return true
  case "0", "false", "no", "off":
    return false
  default:
    return nil
  }
}
