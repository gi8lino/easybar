import EasyBarShared
import Foundation

extension Config {
  /// Restores defaults derived from the current runtime environment.
  func resetDerivedDefaults() {
    let runtime = SharedRuntimeConfig.current

    appSection.widgetsPath =
      FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/widgets")
      .path
    appSection.lockDirectory = runtime.lockDirectory

    loggingSection.directory = runtime.loggingDirectory

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
    appSection.luaPath = "/opt/homebrew/bin/lua"
    appSection.watchConfigFile = false
  }

  /// Restores logging defaults.
  func resetLoggingDefaults() {
    loggingSection.enabled = false
    loggingSection.debugEnabled = false
  }

  /// Restores agent defaults.
  func resetAgentDefaults() {
    calendarAgentSection.enabled = true

    networkAgentSection.enabled = true
    networkAgentSection.refreshIntervalSeconds = 60
    networkAgentSection.allowUnauthorizedNonSensitiveFields = false
  }
}
