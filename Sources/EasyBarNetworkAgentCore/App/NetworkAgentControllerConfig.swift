import EasyBarShared
import Foundation

public struct NetworkAgentControllerConfig {
  public let isEnabled: Bool
  public let processName: String
  public let componentName: String
  public let appVersion: String
  public let configPath: String
  public let socketPath: String
  public let refreshIntervalSeconds: TimeInterval
  public let allowUnauthorizedFieldsWithoutLocation: Bool

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

  public static func easyBar(
    runtimeConfig: SharedRuntimeConfig,
    appVersion: String
  ) -> NetworkAgentControllerConfig {
    NetworkAgentControllerConfig(
      isEnabled: runtimeConfig.networkAgentEnabled,
      processName: "network agent",
      componentName: "network agent",
      appVersion: appVersion,
      configPath: runtimeConfig.configPath,
      socketPath: runtimeConfig.networkAgentSocketPath,
      refreshIntervalSeconds: runtimeConfig.networkAgentRefreshIntervalSeconds,
      allowUnauthorizedFieldsWithoutLocation: runtimeConfig
        .networkAgentAllowUnauthorizedFieldsWithoutLocation
    )
  }
}
