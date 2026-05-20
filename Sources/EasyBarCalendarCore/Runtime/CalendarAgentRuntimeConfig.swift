import EasyBarShared
import Foundation

/// Configuration for one calendar agent runtime instance.
public struct CalendarAgentRuntimeConfig {
  /// Whether the calendar agent is enabled.
  public let isEnabled: Bool
  /// Human-readable process name used in startup logs.
  public let processName: String
  /// Component name used in disabled-state logs.
  public let componentName: String
  /// EasyBar app version reported by the agent.
  public let appVersion: String
  /// Path to the active EasyBar config.
  public let configPath: String
  /// Unix-domain socket path used by the calendar agent.
  public let socketPath: String

  /// Builds one calendar agent runtime config.
  public init(
    isEnabled: Bool,
    processName: String,
    componentName: String,
    appVersion: String,
    configPath: String,
    socketPath: String
  ) {
    self.isEnabled = isEnabled
    self.processName = processName
    self.componentName = componentName
    self.appVersion = appVersion
    self.configPath = configPath
    self.socketPath = socketPath
  }

  /// Builds the default EasyBar calendar agent runtime config.
  public static func easyBar(
    runtimeConfig: SharedRuntimeConfig,
    appVersion: String
  ) -> CalendarAgentRuntimeConfig {
    CalendarAgentRuntimeConfig(
      isEnabled: runtimeConfig.calendarAgentEnabled,
      processName: "calendar agent",
      componentName: "calendar agent",
      appVersion: appVersion,
      configPath: runtimeConfig.configPath,
      socketPath: runtimeConfig.calendarAgentSocketPath
    )
  }
}
