import Foundation

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

  public var loggingLevel: ProcessLogLevel {
    logging.level
  }

  public var loggingDebugEnabled: Bool {
    logging.level.allows(.debug)
  }

  public var loggingTraceEnabled: Bool {
    logging.level.allows(.trace)
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
  public let level: ProcessLogLevel
  public let directory: String

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
