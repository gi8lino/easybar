import Foundation

/// Resolved runtime config shared by helper processes and the CLI.
public struct SharedRuntimeConfig {
  public let configPath: String
  public let app: SharedAppRuntimeConfig
  public let logging: SharedLoggingRuntimeConfig
  public let easyBar: SharedEasyBarRuntimeConfig
  public let calendarAgent: SharedCalendarAgentRuntimeConfig
  public let networkAgent: SharedNetworkAgentRuntimeConfig

  public static let current: SharedRuntimeConfig = {
    do {
      return try load()
    } catch {
      fatalError("failed to load shared runtime config: \(error.localizedDescription)")
    }
  }()

  /// Loads the shared runtime config once from env, defaults, and config.toml.
  public static func load() throws -> SharedRuntimeConfig {
    let configPath = resolvedConfigPath()
    let toml = try parsedConfig(at: configPath)

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

  // MARK: - Compatibility accessors

  /// Compatibility accessor for the widgets path.
  public var widgetsPath: String {
    return app.widgetsPath
  }

  /// Compatibility accessor for the lock directory.
  public var lockDirectory: String {
    return app.lockDirectory
  }

  /// Compatibility accessor for the Lua runtime socket path.
  public var luaSocketPath: String {
    return app.luaSocketPath
  }

  /// Compatibility accessor for the editor stub path.
  public var widgetEditorStubPath: String {
    return app.widgetEditorStubPath
  }

  /// Compatibility accessor for logging enablement.
  public var loggingEnabled: Bool {
    return logging.enabled
  }

  /// Compatibility accessor for the log level.
  public var loggingLevel: ProcessLogLevel {
    return logging.level
  }

  /// Compatibility accessor for the log directory.
  public var loggingDirectory: String {
    return logging.directory
  }

  /// Compatibility accessor for the EasyBar socket path.
  public var easyBarSocketPath: String {
    return easyBar.socketPath
  }

  /// Compatibility accessor for calendar-agent enablement.
  public var calendarAgentEnabled: Bool {
    return calendarAgent.enabled
  }

  /// Compatibility accessor for the calendar-agent socket path.
  public var calendarAgentSocketPath: String {
    return calendarAgent.socketPath
  }

  /// Compatibility accessor for network-agent enablement.
  public var networkAgentEnabled: Bool {
    return networkAgent.enabled
  }

  /// Compatibility accessor for the network-agent socket path.
  public var networkAgentSocketPath: String {
    return networkAgent.socketPath
  }

  /// Compatibility accessor for the network-agent refresh interval.
  public var networkAgentRefreshIntervalSeconds: TimeInterval {
    return networkAgent.refreshIntervalSeconds
  }

  /// Compatibility accessor for unauthorized non-sensitive fields.
  public var networkAgentAllowUnauthorizedFieldsWithoutLocation: Bool {
    return networkAgent.allowUnauthorizedFieldsWithoutLocation
  }

  /// Compatibility alias for unauthorized non-sensitive fields.
  public var networkAgentAllowUnauthorizedNonSensitiveFields: Bool {
    return networkAgent.allowUnauthorizedFieldsWithoutLocation
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
