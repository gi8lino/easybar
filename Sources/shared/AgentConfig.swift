import Foundation

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

/// Returns the configured agent socket path from config.toml.
func configuredAgentSocketPath(section: String) -> String? {
  guard let text = sharedConfigFileText() else { return nil }

  var inAgentSection = false

  for rawLine in text.components(separatedBy: .newlines) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !line.isEmpty, !line.hasPrefix("#") else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      inAgentSection = (line == "[agents.\(section)]")
      continue
    }

    guard inAgentSection, line.hasPrefix("socket_path") else { continue }
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

/// Returns one integer agent value from config.toml.
func configuredAgentIntValue(section: String, key: String) -> Int? {
  guard let text = sharedConfigFileText() else { return nil }

  var inAgentSection = false

  for rawLine in text.components(separatedBy: .newlines) {
    let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !line.isEmpty, !line.hasPrefix("#") else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      inAgentSection = (line == "[agents.\(section)]")
      continue
    }

    guard inAgentSection, line.hasPrefix(key) else { continue }
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
