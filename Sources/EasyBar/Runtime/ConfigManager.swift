import EasyBarShared
import Foundation

/// Actor-owned access to config mutation and runtime-facing config reads.
actor ConfigManager {
  static let shared = ConfigManager()

  struct ReloadResult: Sendable {
    let succeeded: Bool
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
