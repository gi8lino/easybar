import EasyBarShared
import Foundation

/// Actor-owned access to config mutation and runtime-facing config reads.
actor ConfigManager {
  struct ValidationResult: Sendable {
    /// Resolved path of the validated config file.
    let configPath: String
    /// User-facing validation error when validation failed.
    let errorMessage: String?
  }

  struct LuaCommandSettings: Sendable {
    let timeoutSeconds: TimeInterval
    let maxOutputBytes: Int
    let maxAsyncJobs: Int
  }

  /// Shared actor used for runtime config access.
  static var shared = ConfigManager()

  /// Result of one config reload attempt.
  struct ReloadResult: Sendable {
    /// Whether reload completed without validation errors.
    let succeeded: Bool
    /// User-facing reload error when reload failed.
    let errorMessage: String?
  }

  /// Loads the active config during app startup and returns a stable result.
  func loadInitialConfig() async -> ReloadResult {
    await MainActor.run {
      let error = Config.shared.loadInitialState()

      if let error {
        return ReloadResult(
          succeeded: false,
          errorMessage: String(describing: error)
        )
      }

      return ReloadResult(
        succeeded: true,
        errorMessage: nil
      )
    }
  }

  /// Reloads the active config and returns a stable result.
  func reload() async -> ReloadResult {
    await MainActor.run {
      let error = Config.shared.reload()

      if let error {
        return ReloadResult(
          succeeded: false,
          errorMessage: String(describing: error)
        )
      }

      return ReloadResult(
        succeeded: true,
        errorMessage: nil
      )
    }
  }

  /// Validates config without mutating live runtime state.
  func validateConfig(configPathOverride: String? = nil) async -> ValidationResult {
    await MainActor.run {
      do {
        let result = try ConfigValidator.validate(configPathOverride: configPathOverride)
        return ValidationResult(
          configPath: result.configPath,
          errorMessage: nil
        )
      } catch {
        return ValidationResult(
          configPath: Self.resolvedValidationConfigPath(configPathOverride),
          errorMessage: Self.validationErrorMessage(error)
        )
      }
    }
  }

  /// Returns whether config watching is enabled.
  func watchConfigFileEnabled() async -> Bool {
    await MainActor.run {
      Config.shared.watchConfigFile
    }
  }

  /// Returns the active config path.
  func configPath() async -> String {
    await MainActor.run {
      Config.shared.configPath
    }
  }

  /// Returns the active EasyBar socket path.
  func easyBarSocketPath() async -> String {
    return SharedRuntimeConfig.environmentDefaults().easyBarSocketPath
  }

  /// Returns the current minimum log level.
  func loggingLevel() async -> ProcessLogLevel {
    await MainActor.run {
      Config.shared.loggingLevel
    }
  }

  /// Returns whether file logging is enabled.
  func loggingEnabled() async -> Bool {
    await MainActor.run {
      Config.shared.loggingEnabled
    }
  }

  /// Returns the configured logging directory.
  func loggingDirectory() async -> String {
    await MainActor.run {
      Config.shared.loggingDirectory
    }
  }

  /// Returns the current Lua command execution settings.
  func luaCommandSettings() async -> LuaCommandSettings {
    await MainActor.run {
      LuaCommandSettings(
        timeoutSeconds: Config.shared.luaCommandTimeoutSeconds,
        maxOutputBytes: Config.shared.luaCommandMaxOutputBytes,
        maxAsyncJobs: Config.shared.luaCommandMaxAsyncJobs
      )
    }
  }

  /// Returns the resolved config path used for validation status and errors.
  private static func resolvedValidationConfigPath(_ configPathOverride: String?) -> String {
    if let resolvedOverride = expandedPath(configPathOverride) {
      return resolvedOverride
    }

    return expandedEnvironmentPath(named: SharedEnvironmentKeys.configPath)
      ?? SharedPathDefaults.defaultConfigPath().path
  }

  /// Returns a concise user-facing validation error message.
  private static func validationErrorMessage(_ error: any Error) -> String {
    if let localizedError = error as? LocalizedError,
      let description = localizedError.errorDescription,
      !description.isEmpty
    {
      return description
    }

    return "\(error)"
  }
}
