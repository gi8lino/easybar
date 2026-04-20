import EasyBarShared
import Foundation

extension Config {
  /// Restores defaults derived from the current runtime environment.
  func resetDerivedDefaults() {
    let runtime = SharedRuntimeConfig.current

    appSection.widgetsPath = runtime.widgetsPath
    appSection.lockDirectory = runtime.lockDirectory

    loggingSection.directory = runtime.loggingDirectory
    loggingSection.level = runtime.loggingLevel

    calendarAgentSection.socketPath = runtime.calendarAgentSocketPath

    networkAgentSection.socketPath = runtime.networkAgentSocketPath
    networkAgentSection.refreshIntervalSeconds = runtime.networkAgentRefreshIntervalSeconds
    networkAgentSection.allowUnauthorizedNonSensitiveFields =
      runtime.networkAgentAllowUnauthorizedNonSensitiveFields
  }

  /// Restores all static defaults before parsing again.
  func resetStaticDefaults() {
    resetAppDefaults()
    resetLoggingDefaults()
    resetAgentDefaults()
    resetBarDefaults()
    resetBuiltinDefaults()
  }

  /// Restores app-level defaults.
  func resetAppDefaults() {
    appSection.luaPath = SharedPathDefaults.defaultLuaPath
    appSection.environment = SharedPathDefaults.defaultLuaEnvironment
    appSection.watchConfigFile = true
  }

  /// Returns the configured app environment merged onto the runtime defaults.
  static func mergedAppEnvironment(with configured: [String: String]) -> [String: String] {
    SharedPathDefaults.defaultLuaEnvironment.merging(configured) { _, configuredValue in
      configuredValue
    }
  }

  /// Restores logging defaults.
  func resetLoggingDefaults() {
    loggingSection.enabled = false
    loggingSection.level = .info
  }

  /// Restores agent defaults.
  func resetAgentDefaults() {
    calendarAgentSection.enabled = true

    networkAgentSection.enabled = true
    networkAgentSection.refreshIntervalSeconds = 60
    networkAgentSection.allowUnauthorizedNonSensitiveFields = false
  }
}
