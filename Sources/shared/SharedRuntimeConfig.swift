import Foundation
import TOMLKit

/// Resolved runtime config shared by helper processes and the CLI.
public struct SharedRuntimeConfig {
  public let configPath: String
  public let loggingEnabled: Bool
  public let loggingDebugEnabled: Bool
  public let loggingDirectory: String
  public let easyBarSocketPath: String
  public let calendarAgentSocketPath: String
  public let networkAgentSocketPath: String
  public let networkAgentRefreshIntervalSeconds: TimeInterval

  public static let current = load()

  /// Loads the shared runtime config once from env, defaults, and config.toml.
  public static func load() -> SharedRuntimeConfig {
    let configPath = resolvedConfigPath()
    let toml = parsedConfig(at: configPath)

    let loggingTable = toml["logging"]?.table
    let calendarTable = toml["agents"]?["calendar"]?.table
    let networkTable = toml["agents"]?["network"]?.table

    let loggingEnabled = boolEnv("EASYBAR_LOGGING_ENABLED")
      ?? loggingTable?["enabled"]?.bool
      ?? false

    let loggingDebugEnabled = boolEnv("EASYBAR_DEBUG")
      ?? loggingTable?["debug"]?.bool
      ?? false

    let loggingDirectory =
      expandedPath(
        loggingTable?["directory"]?.string
      ) ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/state/easybar")
        .path

    let easyBarSocketPath =
      expandedPath(stringEnv("EASYBAR_SOCKET_PATH"))
      ?? "/tmp/EasyBar/easybar.sock"

    let calendarAgentSocketPath =
      expandedPath(stringEnv("EASYBAR_CALENDAR_AGENT_SOCKET"))
      ?? expandedPath(calendarTable?["socket_path"]?.string)
      ?? "/tmp/EasyBar/calendar-agent.sock"

    let networkAgentSocketPath =
      expandedPath(stringEnv("EASYBAR_NETWORK_AGENT_SOCKET"))
      ?? expandedPath(networkTable?["socket_path"]?.string)
      ?? "/tmp/EasyBar/network-agent.sock"

    let networkAgentRefreshIntervalSeconds =
      timeIntervalEnv("EASYBAR_NETWORK_AGENT_REFRESH_INTERVAL_SECONDS")
      ?? networkTable?["refresh_interval_seconds"]?.double
      ?? 60

    return SharedRuntimeConfig(
      configPath: configPath,
      loggingEnabled: loggingEnabled,
      loggingDebugEnabled: loggingDebugEnabled,
      loggingDirectory: loggingDirectory,
      easyBarSocketPath: easyBarSocketPath,
      calendarAgentSocketPath: calendarAgentSocketPath,
      networkAgentSocketPath: networkAgentSocketPath,
      networkAgentRefreshIntervalSeconds: networkAgentRefreshIntervalSeconds
    )
  }
}

/// Returns the resolved EasyBar config path, honoring EASYBAR_CONFIG_PATH.
private func resolvedConfigPath() -> String {
  expandedPath(stringEnv("EASYBAR_CONFIG_PATH"))
    ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/config.toml")
      .path
}

/// Returns one parsed TOML table or an empty table when loading fails.
private func parsedConfig(at path: String) -> TOMLTable {
  guard
    let text = try? String(contentsOfFile: path, encoding: .utf8),
    let table = try? TOMLTable(string: text)
  else {
    return TOMLTable()
  }

  return table
}

/// Returns one non-empty string environment value.
private func stringEnv(_ name: String) -> String? {
  guard
    let value = ProcessInfo.processInfo.environment[name]?
      .trimmingCharacters(in: .whitespacesAndNewlines),
    !value.isEmpty
  else {
    return nil
  }

  return value
}

/// Returns one boolean environment value when it is valid.
private func boolEnv(_ name: String) -> Bool? {
  guard let value = stringEnv(name) else { return nil }

  switch value.lowercased() {
  case "1", "true", "yes", "on":
    return true
  case "0", "false", "no", "off":
    return false
  default:
    return nil
  }
}

/// Returns one numeric environment value when it is valid.
private func timeIntervalEnv(_ name: String) -> TimeInterval? {
  guard let value = stringEnv(name) else { return nil }
  return TimeInterval(value)
}

/// Expands `~` when present and returns one non-empty path string.
private func expandedPath(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }
  return NSString(string: value).expandingTildeInPath
}
