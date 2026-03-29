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

    let loggingEnabled = boolEnvironmentValue(named: "EASYBAR_LOGGING_ENABLED")
      ?? loggingTable?["enabled"]?.bool
      ?? false

    let loggingDebugEnabled = boolEnvironmentValue(named: "EASYBAR_DEBUG")
      ?? loggingTable?["debug"]?.bool
      ?? false

    let loggingDirectory =
      expandedPath(
        loggingTable?["directory"]?.string
      ) ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/state/easybar")
        .path

    let easyBarSocketPath =
      expandedEnvironmentPath(named: "EASYBAR_SOCKET_PATH")
      ?? "/tmp/EasyBar/easybar.sock"

    let calendarAgentSocketPath =
      expandedEnvironmentPath(named: "EASYBAR_CALENDAR_AGENT_SOCKET")
      ?? expandedPath(calendarTable?["socket_path"]?.string)
      ?? "/tmp/EasyBar/calendar-agent.sock"

    let networkAgentSocketPath =
      expandedEnvironmentPath(named: "EASYBAR_NETWORK_AGENT_SOCKET")
      ?? expandedPath(networkTable?["socket_path"]?.string)
      ?? "/tmp/EasyBar/network-agent.sock"

    let networkAgentRefreshIntervalSeconds =
      timeIntervalEnvironmentValue(named: "EASYBAR_NETWORK_AGENT_REFRESH_INTERVAL_SECONDS")
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
  expandedEnvironmentPath(named: "EASYBAR_CONFIG_PATH")
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
