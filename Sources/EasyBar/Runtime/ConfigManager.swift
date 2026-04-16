import Foundation

/// Actor-owned facade around the global config object.
///
/// The app still uses `Config.shared` as the source of truth for now, but all
/// reload orchestration should go through this actor so config mutation has one
/// owner in the runtime layer.
actor ConfigManager {
  static let shared = ConfigManager()

  struct ReloadResult: Sendable {
    let succeeded: Bool
    let errorMessage: String?
  }

  /// Reloads the active config on the main actor.
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

  /// Returns whether config file watching is currently enabled.
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

  /// Returns the configured logging level.
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

  /// Returns the current config failure state.
  func loadFailureState() async -> Config.LoadFailureState? {
    await MainActor.run {
      Config.shared.loadFailureState
    }
  }

  /// Returns the current config path for the error window.
  func errorWindowConfigPath() async -> String {
    await MainActor.run {
      Config.shared.configPath
    }
  }
}
