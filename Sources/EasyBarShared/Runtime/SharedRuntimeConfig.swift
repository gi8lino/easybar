import Foundation
import TOMLKit

/// Resolved runtime config shared by helper processes and the CLI.
public struct SharedRuntimeConfig {
  public let configPath: String
  public let app: SharedAppRuntimeConfig
  public let logging: SharedLoggingRuntimeConfig
  public let easyBar: SharedEasyBarRuntimeConfig
  public let calendarAgent: SharedCalendarAgentRuntimeConfig
  public let networkAgent: SharedNetworkAgentRuntimeConfig

  public static let current = load()

  /// Loads the shared runtime config once from env, defaults, and config.toml.
  public static func load() -> SharedRuntimeConfig {
    let configPath = resolvedConfigPath()
    let toml = parsedConfig(at: configPath)

    let app = resolvedAppConfig(from: toml)
    let logging = resolvedLoggingConfig(from: toml)
    let easyBar = resolvedEasyBarConfig(from: toml)
    let calendarAgent = resolvedCalendarAgentConfig(from: toml)
    let networkAgent = resolvedNetworkAgentConfig(from: toml)

    return SharedRuntimeConfig(
      configPath: configPath,
      app: app,
      logging: logging,
      easyBar: easyBar,
      calendarAgent: calendarAgent,
      networkAgent: networkAgent
    )
  }

  // MARK: - Compatibility accessors

  public var lockDirectory: String {
    app.lockDirectory
  }

  public var loggingEnabled: Bool {
    logging.enabled
  }

  public var loggingDebugEnabled: Bool {
    logging.debugEnabled
  }

  public var loggingDirectory: String {
    logging.directory
  }

  public var easyBarSocketPath: String {
    easyBar.socketPath
  }

  public var calendarAgentEnabled: Bool {
    calendarAgent.enabled
  }

  public var calendarAgentSocketPath: String {
    calendarAgent.socketPath
  }

  public var networkAgentEnabled: Bool {
    networkAgent.enabled
  }

  public var networkAgentSocketPath: String {
    networkAgent.socketPath
  }

  public var networkAgentRefreshIntervalSeconds: TimeInterval {
    networkAgent.refreshIntervalSeconds
  }

  public var networkAgentAllowUnauthorizedFieldsWithoutLocation: Bool {
    networkAgent.allowUnauthorizedFieldsWithoutLocation
  }

  public var networkAgentAllowUnauthorizedNonSensitiveFields: Bool {
    networkAgent.allowUnauthorizedFieldsWithoutLocation
  }
}

/// Resolved app-level values shared by helper processes.
public struct SharedAppRuntimeConfig {
  public let lockDirectory: String

  public init(lockDirectory: String) {
    self.lockDirectory = lockDirectory
  }
}

/// Resolved logging values shared by helper processes.
public struct SharedLoggingRuntimeConfig {
  public let enabled: Bool
  public let debugEnabled: Bool
  public let directory: String

  public init(
    enabled: Bool,
    debugEnabled: Bool,
    directory: String
  ) {
    self.enabled = enabled
    self.debugEnabled = debugEnabled
    self.directory = directory
  }
}

/// Resolved EasyBar socket values shared by helper processes.
public struct SharedEasyBarRuntimeConfig {
  public let socketPath: String

  public init(socketPath: String) {
    self.socketPath = socketPath
  }
}

/// Resolved calendar-agent values shared by helper processes.
public struct SharedCalendarAgentRuntimeConfig {
  public let enabled: Bool
  public let socketPath: String

  public init(
    enabled: Bool,
    socketPath: String
  ) {
    self.enabled = enabled
    self.socketPath = socketPath
  }
}

/// Resolved network-agent values shared by helper processes.
public struct SharedNetworkAgentRuntimeConfig {
  public let enabled: Bool
  public let socketPath: String
  public let refreshIntervalSeconds: TimeInterval
  public let allowUnauthorizedFieldsWithoutLocation: Bool

  public init(
    enabled: Bool,
    socketPath: String,
    refreshIntervalSeconds: TimeInterval,
    allowUnauthorizedFieldsWithoutLocation: Bool
  ) {
    self.enabled = enabled
    self.socketPath = socketPath
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.allowUnauthorizedFieldsWithoutLocation = allowUnauthorizedFieldsWithoutLocation
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

/// Returns the resolved app config from env, TOML, and defaults.
private func resolvedAppConfig(from toml: TOMLTable) -> SharedAppRuntimeConfig {
  let appTable = toml["app"]?.table

  let lockDirectory =
    expandedEnvironmentPath(named: "EASYBAR_LOCK_DIR")
    ?? expandedPath(appTable?["lock_dir"]?.string)
    ?? defaultSingleInstanceLockDirectoryPath()

  return SharedAppRuntimeConfig(
    lockDirectory: lockDirectory
  )
}

/// Returns the resolved logging config from env, TOML, and defaults.
private func resolvedLoggingConfig(from toml: TOMLTable) -> SharedLoggingRuntimeConfig {
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
    expandedEnvironmentPath(named: "EASYBAR_LOGGING_DIRECTORY")
    ?? expandedPath(loggingTable?["directory"]?.string)
    ?? defaultLoggingDirectoryPath()

  return SharedLoggingRuntimeConfig(
    enabled: enabled,
    debugEnabled: debugEnabled,
    directory: directory
  )
}

/// Returns the resolved EasyBar socket config from env, TOML, and defaults.
private func resolvedEasyBarConfig(from toml: TOMLTable) -> SharedEasyBarRuntimeConfig {
  SharedEasyBarRuntimeConfig(
    socketPath: resolvedSocketPath(
      environmentName: "EASYBAR_SOCKET_PATH",
      tomlValue: nil,
      fallback: defaultEasyBarSocketPath
    )
  )
}

/// Returns the resolved calendar-agent config from env, TOML, and defaults.
private func resolvedCalendarAgentConfig(from toml: TOMLTable) -> SharedCalendarAgentRuntimeConfig {
  let calendarTable = toml["agents"]?["calendar"]?.table

  let enabled =
    boolEnvironmentValue(named: "EASYBAR_CALENDAR_AGENT_ENABLED")
    ?? calendarTable?["enabled"]?.bool
    ?? true

  let socketPath =
    resolvedSocketPath(
      environmentName: "EASYBAR_CALENDAR_AGENT_SOCKET",
      tomlValue: calendarTable?["socket_path"]?.string,
      fallback: defaultCalendarAgentSocketPath
    )

  return SharedCalendarAgentRuntimeConfig(
    enabled: enabled,
    socketPath: socketPath
  )
}

/// Returns the resolved network-agent config from env, TOML, and defaults.
private func resolvedNetworkAgentConfig(from toml: TOMLTable) -> SharedNetworkAgentRuntimeConfig {
  let networkTable = toml["agents"]?["network"]?.table

  let enabled =
    boolEnvironmentValue(named: "EASYBAR_NETWORK_AGENT_ENABLED")
    ?? networkTable?["enabled"]?.bool
    ?? true

  let socketPath =
    resolvedSocketPath(
      environmentName: "EASYBAR_NETWORK_AGENT_SOCKET",
      tomlValue: networkTable?["socket_path"]?.string,
      fallback: defaultNetworkAgentSocketPath
    )

  let refreshIntervalSeconds =
    timeIntervalEnvironmentValue(named: "EASYBAR_NETWORK_AGENT_REFRESH_INTERVAL_SECONDS")
    ?? networkTable?["refresh_interval_seconds"]?.double
    ?? 60

  let allowUnauthorizedFieldsWithoutLocation =
    boolEnvironmentValue(named: "EASYBAR_NETWORK_AGENT_ALLOW_UNAUTHORIZED_NON_SENSITIVE_FIELDS")
    ?? networkTable?["allow_unauthorized_non_sensitive_fields"]?.bool
    ?? false

  return SharedNetworkAgentRuntimeConfig(
    enabled: enabled,
    socketPath: socketPath,
    refreshIntervalSeconds: refreshIntervalSeconds,
    allowUnauthorizedFieldsWithoutLocation: allowUnauthorizedFieldsWithoutLocation
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
