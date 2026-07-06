import EasyBarShared
import Foundation

/// Configuration for one network agent runtime instance.
public struct NetworkAgentRuntimeConfig {
  /// Whether this runtime should start.
  public let isEnabled: Bool
  /// Process name used in startup logs.
  public let processName: String
  /// Component name used in log labels.
  public let componentName: String
  /// Application version advertised on the socket.
  public let appVersion: String
  /// Resolved config file path.
  public let configPath: String
  /// Unix socket path for the agent.
  public let socketPath: String
  /// Periodic refresh interval.
  public let refreshIntervalSeconds: TimeInterval
  /// Whether non-sensitive fields are allowed before authorization.
  public let allowUnauthorizedFieldsWithoutLocation: Bool

  /// Builds one network agent runtime config.
  public init(
    isEnabled: Bool,
    processName: String,
    componentName: String,
    appVersion: String,
    configPath: String,
    socketPath: String,
    refreshIntervalSeconds: TimeInterval,
    allowUnauthorizedFieldsWithoutLocation: Bool
  ) {
    self.isEnabled = isEnabled
    self.processName = processName
    self.componentName = componentName
    self.appVersion = appVersion
    self.configPath = configPath
    self.socketPath = socketPath
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.allowUnauthorizedFieldsWithoutLocation = allowUnauthorizedFieldsWithoutLocation
  }

  /// Builds the default EasyBar network agent runtime config.
  public static func easyBar(
    runtimeConfig: SharedRuntimeConfig,
    appVersion: String
  ) -> NetworkAgentRuntimeConfig {
    NetworkAgentRuntimeConfig(
      isEnabled: runtimeConfig.networkAgent.enabled,
      processName: "network agent",
      componentName: "network agent",
      appVersion: appVersion,
      configPath: runtimeConfig.configPath,
      socketPath: runtimeConfig.networkAgent.socketPath,
      refreshIntervalSeconds: runtimeConfig.networkAgent.refreshIntervalSeconds,
      allowUnauthorizedFieldsWithoutLocation: runtimeConfig
        .networkAgent.allowUnauthorizedFieldsWithoutLocation
    )
  }
}
