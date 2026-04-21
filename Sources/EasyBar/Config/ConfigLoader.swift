import EasyBarShared
import Foundation
import TOMLKit

extension Config {

  /// Loads configuration from disk.
  ///
  /// Resolution order:
  /// - built-in defaults already present on the config instance
  /// - TOML file values when the config file exists
  /// - per-section environment overrides
  /// - per-section directory registration
  /// - required directory creation
  func load() throws {
    resetRegisteredDirectories()

    let resolvedConfigPath = configPath
    let fileURL = URL(fileURLWithPath: resolvedConfigPath)
    let fileManager = FileManager.default

    if fileManager.fileExists(atPath: fileURL.path) {
      let data: Data

      do {
        data = try Data(contentsOf: fileURL)
      } catch {
        throw ConfigError.invalidValue(
          path: "config",
          message: "failed to read file at \(resolvedConfigPath): \(error.localizedDescription)"
        )
      }

      guard let text = String(data: data, encoding: .utf8) else {
        throw ConfigError.invalidValue(
          path: "config",
          message: "file is not valid UTF-8"
        )
      }

      do {
        let toml = try TOMLTable(string: text)

        try parseApp(from: toml)
        try parseLogging(from: toml)
        try parseAgents(from: toml)
        try parseBar(from: toml)
        try parseBuiltins(from: toml)
      } catch let error as ConfigError {
        throw error
      } catch {
        throw ConfigError.invalidValue(
          path: "config",
          message: "parse failed: \(error)"
        )
      }
    } else {
      easybarLog.info("using default configuration from \(resolvedConfigPath)")

      try parseApp(from: TOMLTable())
      try parseLogging(from: TOMLTable())
      try parseAgents(from: TOMLTable())
      try parseBar(from: TOMLTable())
    }

    try ensureRequiredDirectoriesExist()
  }

  /// Returns the config path override from the environment when present.
  func environmentConfigPathOverride() -> String? {
    expandedEnvironmentPath(named: SharedEnvironmentKeys.configPath)
  }

  /// Returns the log-level override from the environment when present.
  func environmentLogLevelOverride() throws -> ProcessLogLevel? {
    guard let value = stringEnvironmentValue(named: SharedEnvironmentKeys.loggingLevel) else {
      return nil
    }

    return try parseLogLevel(
      value,
      path: "environment.\(SharedEnvironmentKeys.loggingLevel)"
    )
  }
}
