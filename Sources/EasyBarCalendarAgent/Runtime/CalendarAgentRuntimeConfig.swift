import EasyBarShared
import Foundation

/// Configuration for one calendar agent runtime instance.
struct CalendarAgentRuntimeConfig {
  let isEnabled: Bool
  let processName: String
  let componentName: String
  let appVersion: String
  let configPath: String
  let socketPath: String

  /// Builds one calendar agent runtime config.
  init(
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
  static func easyBar(
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
