import EasyBarShared
import Foundation

/// Actor-owned access to config mutation and runtime-facing config reads.
actor ConfigManager {
  /// Shared actor used for runtime config access.
  static let shared = ConfigManager()

  /// Result of one config reload attempt.
  struct ReloadResult: Sendable {
    /// Whether reload completed without validation errors.
    let succeeded: Bool
    /// User-facing reload error when reload failed.
    let errorMessage: String?
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
    SharedRuntimeConfig.environmentDefaults().easyBarSocketPath
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
}
