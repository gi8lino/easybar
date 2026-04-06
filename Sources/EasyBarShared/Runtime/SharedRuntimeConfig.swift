import Foundation
import TOMLKit

/// Resolved runtime config shared by helper processes and the CLI.
public struct SharedRuntimeConfig {
  public let configPath: String
  public let lockDirectory: String
  public let loggingEnabled: Bool
  public let loggingDebugEnabled: Bool
  public let loggingDirectory: String
  public let easyBarSocketPath: String
  public let calendarAgentEnabled: Bool
  public let calendarAgentSocketPath: String
  public let networkAgentEnabled: Bool
  public let networkAgentSocketPath: String
  public let networkAgentRefreshIntervalSeconds: TimeInterval
  public let networkAgentAllowUnauthorizedNonSensitiveFields: Bool

  public static let current = load()

  /// Loads the shared runtime config once from env, defaults, and config.toml.
  public static func load() -> SharedRuntimeConfig {
    let configPath = resolvedConfigPath()
    let toml = parsedConfig(at: configPath)
    let app = resolvedAppConfig(from: toml)
    let logging = resolvedLoggingConfig(from: toml)
    let sockets = resolvedSocketConfig(from: toml)

    return SharedRuntimeConfig(
      configPath: configPath,
      lockDirectory: app.lockDirectory,
      loggingEnabled: logging.enabled,
      loggingDebugEnabled: logging.debugEnabled,
      loggingDirectory: logging.directory,
      easyBarSocketPath: sockets.easyBarSocketPath,
      calendarAgentEnabled: sockets.calendarAgentEnabled,
      calendarAgentSocketPath: sockets.calendarAgentSocketPath,
      networkAgentEnabled: sockets.networkAgentEnabled,
      networkAgentSocketPath: sockets.networkAgentSocketPath,
      networkAgentRefreshIntervalSeconds: sockets.networkAgentRefreshIntervalSeconds,
      networkAgentAllowUnauthorizedNonSensitiveFields: sockets
        .networkAgentAllowUnauthorizedNonSensitiveFields
    )
  }
}

/// Resolved app-level values shared by helper processes.
private struct SharedAppConfig {
  let lockDirectory: String
}

/// Resolved logging values shared by helper processes.
private struct SharedLoggingConfig {
  let enabled: Bool
  let debugEnabled: Bool
  let directory: String
}

/// Resolved socket values shared by helper processes.
private struct SharedSocketConfig {
  let easyBarSocketPath: String
  let calendarAgentEnabled: Bool
  let calendarAgentSocketPath: String
  let networkAgentEnabled: Bool
  let networkAgentSocketPath: String
  let networkAgentRefreshIntervalSeconds: TimeInterval
  let networkAgentAllowUnauthorizedNonSensitiveFields: Bool
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

/// Returns the resolved app config from env, TOML, and defaults.
private func resolvedAppConfig(from toml: TOMLTable) -> SharedAppConfig {
  let appTable = toml["app"]?.table

  let lockDirectory =
    expandedEnvironmentPath(named: "EASYBAR_LOCK_DIR")
    ?? expandedPath(appTable?["lock_dir"]?.string)
    ?? defaultSingleInstanceLockDirectoryPath()

  return SharedAppConfig(
    lockDirectory: lockDirectory
  )
}

/// Returns the resolved logging config from env, TOML, and defaults.
private func resolvedLoggingConfig(from toml: TOMLTable) -> SharedLoggingConfig {
  let loggingTable = toml["logging"]?.table

  let enabled =
    boolEnvironmentValue(named: "EASYBAR_LOGGING_ENABLED")
    ?? loggingTable?["enabled"]?.bool
    ?? false

  let debugEnabled =
    boolEnvironmentValue(named: "EASYBAR_DEBUG")
    ?? loggingTable?["debug"]?.bool
    ?? false

  let directory =
    expandedPath(loggingTable?["directory"]?.string)
    ?? defaultLoggingDirectoryPath()

  return SharedLoggingConfig(
    enabled: enabled,
    debugEnabled: debugEnabled,
    directory: directory
  )
}

/// Returns the resolved socket and agent config from env, TOML, and defaults.
private func resolvedSocketConfig(from toml: TOMLTable) -> SharedSocketConfig {
  let calendarTable = toml["agents"]?["calendar"]?.table
  let networkTable = toml["agents"]?["network"]?.table

  let easyBarSocketPath =
    resolvedSocketPath(
      environmentName: "EASYBAR_SOCKET_PATH",
      tomlValue: nil,
      fallback: defaultEasyBarSocketPath
    )

  let calendarAgentEnabled = calendarTable?["enabled"]?.bool ?? true
  let calendarAgentSocketPath =
    resolvedSocketPath(
      environmentName: "EASYBAR_CALENDAR_AGENT_SOCKET",
      tomlValue: calendarTable?["socket_path"]?.string,
      fallback: defaultCalendarAgentSocketPath
    )

  let networkAgentEnabled = networkTable?["enabled"]?.bool ?? true
  let networkAgentSocketPath =
    resolvedSocketPath(
      environmentName: "EASYBAR_NETWORK_AGENT_SOCKET",
      tomlValue: networkTable?["socket_path"]?.string,
      fallback: defaultNetworkAgentSocketPath
    )

  let networkAgentRefreshIntervalSeconds =
    timeIntervalEnvironmentValue(named: "EASYBAR_NETWORK_AGENT_REFRESH_INTERVAL_SECONDS")
    ?? networkTable?["refresh_interval_seconds"]?.double
    ?? 60
  let networkAgentAllowUnauthorizedNonSensitiveFields =
    networkTable?["allow_unauthorized_non_sensitive_fields"]?.bool
    ?? false

  return SharedSocketConfig(
    easyBarSocketPath: easyBarSocketPath,
    calendarAgentEnabled: calendarAgentEnabled,
    calendarAgentSocketPath: calendarAgentSocketPath,
    networkAgentEnabled: networkAgentEnabled,
    networkAgentSocketPath: networkAgentSocketPath,
    networkAgentRefreshIntervalSeconds: networkAgentRefreshIntervalSeconds,
    networkAgentAllowUnauthorizedNonSensitiveFields: networkAgentAllowUnauthorizedNonSensitiveFields
  )
}

/// Returns one resolved socket path from env, TOML, and fallback defaults.
public func resolvedSocketPath(
  environmentName: String,
  tomlValue: String?,
  fallback: () -> String
) -> String {
  expandedEnvironmentPath(named: environmentName)
    ?? expandedPath(tomlValue)
    ?? fallback()
}

/// Returns the default Unix socket path used by EasyBar.
private func defaultEasyBarSocketPath() -> String {
  "/tmp/EasyBar/easybar.sock"
}

/// Returns the default Unix socket path used by the calendar agent.
private func defaultCalendarAgentSocketPath() -> String {
  "/tmp/EasyBar/calendar-agent.sock"
}

/// Returns the default Unix socket path used by the network agent.
private func defaultNetworkAgentSocketPath() -> String {
  "/tmp/EasyBar/network-agent.sock"
}

/// Returns the default directory used for single-instance lock files.
private func defaultSingleInstanceLockDirectoryPath() -> String {
  "/tmp/EasyBar"
}
