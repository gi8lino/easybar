import Foundation

/// Resolved runtime config shared by helper processes and the CLI.
public struct SharedRuntimeConfig {
  public let configPath: String
  public let app: SharedAppRuntimeConfig
  public let logging: SharedLoggingRuntimeConfig
  public let easyBar: SharedEasyBarRuntimeConfig
  public let calendarAgent: SharedCalendarAgentRuntimeConfig
  public let networkAgent: SharedNetworkAgentRuntimeConfig

  /// Loads the shared runtime config once from env, defaults, and config.toml.
  public static func load() throws -> SharedRuntimeConfig {
    let configPath = resolvedConfigPath()
    let toml = try parsedConfig(at: configPath)
    let reader = sharedRuntimeConfigReader(for: toml)

    let app = try resolvedAppConfig(from: reader)
    let logging = try resolvedLoggingConfig(from: reader)
    let easyBar = try resolvedEasyBarConfig(from: reader)
    let calendarAgent = try resolvedCalendarAgentConfig(from: reader)
    let networkAgent = try resolvedNetworkAgentConfig(from: reader)

    return SharedRuntimeConfig(
      configPath: configPath,
      app: app,
      logging: logging,
      easyBar: easyBar,
      calendarAgent: calendarAgent,
      networkAgent: networkAgent
    )
  }

  /// Resolves runtime defaults from environment overrides and built-in fallbacks only.
  public static func environmentDefaults() -> SharedRuntimeConfig {
    SharedRuntimeConfig(
      configPath: resolvedConfigPath(),
      app: resolvedAppEnvironmentDefaults(),
      logging: resolvedLoggingEnvironmentDefaults(),
      easyBar: resolvedEasyBarEnvironmentDefaults(),
      calendarAgent: resolvedCalendarAgentEnvironmentDefaults(),
      networkAgent: resolvedNetworkAgentEnvironmentDefaults()
    )
  }
}

/// Resolved app-level values shared by helper processes.
public struct SharedAppRuntimeConfig {
  public let widgetsPath: String
  public let lockDirectory: String
  public let luaSocketPath: String
  public let widgetEditorStubPath: String

  /// Creates one app runtime config.
  public init(
    widgetsPath: String,
    lockDirectory: String,
    luaSocketPath: String,
    widgetEditorStubPath: String
  ) {
    self.widgetsPath = widgetsPath
    self.lockDirectory = lockDirectory
    self.luaSocketPath = luaSocketPath
    self.widgetEditorStubPath = widgetEditorStubPath
  }
}

/// Resolved logging values shared by helper processes.
public struct SharedLoggingRuntimeConfig {
  public let enabled: Bool
  public let level: ProcessLogLevel
  public let directory: String

  /// Creates one logging runtime config.
  public init(
    enabled: Bool,
    level: ProcessLogLevel,
    directory: String
  ) {
    self.enabled = enabled
    self.level = level
    self.directory = directory
  }
}

/// Resolved EasyBar socket values shared by helper processes.
public struct SharedEasyBarRuntimeConfig {
  public let socketPath: String

  /// Creates one EasyBar socket config.
  public init(socketPath: String) {
    self.socketPath = socketPath
  }
}

/// Resolved calendar-agent values shared by helper processes.
public struct SharedCalendarAgentRuntimeConfig {
  public let enabled: Bool
  public let socketPath: String

  /// Creates one calendar-agent runtime config.
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

  /// Creates one network-agent runtime config.
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
