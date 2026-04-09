import Foundation
import TOMLKit

extension SharedRuntimeConfig {
  /// Resolves the shared logging config from TOML plus supported environment overrides.
  func resolvedLoggingConfig(from toml: TOMLTable) -> LoggingConfig {
    let loggingTable = toml["logging"]?.table

    let enabled =
      boolEnvironmentValue(named: SharedEnvironmentKeys.loggingEnabled)
      ?? loggingTable?["enabled"]?.bool
      ?? false

    let level = resolvedLoggingLevel(
      tomlValue: loggingTable?["level"]?.string,
      legacyDebugValue: loggingTable?["debug"]?.bool,
      environmentName: SharedEnvironmentKeys.logLevel,
      fallback: .info
    )

    let directory =
      expandedEnvironmentPath(named: SharedEnvironmentKeys.loggingDirectory)
      ?? expandedPath(loggingTable?["directory"]?.string)
      ?? defaultLoggingDirectory()

    return LoggingConfig(
      enabled: enabled,
      level: level,
      directory: directory
    )
  }

  /// Resolves the configured minimum logging level from environment or TOML.
  private func resolvedLoggingLevel(
    tomlValue: String?,
    legacyDebugValue: Bool?,
    environmentName: String,
    fallback: ProcessLogLevel
  ) -> ProcessLogLevel {
    if let raw = stringEnvironmentValue(named: environmentName),
      let level = ProcessLogLevel.normalized(raw)
    {
      return level
    }

    if let tomlValue,
      let level = ProcessLogLevel.normalized(tomlValue)
    {
      return level
    }

    if let legacyDebugValue {
      return legacyDebugValue ? .debug : .info
    }

    return fallback
  }

  /// Returns the default shared logging directory.
  private func defaultLoggingDirectory() -> String {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".local/state/easybar")
      .path
  }

  /// Expands one optional filesystem path.
  private func expandedPath(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return NSString(string: value).expandingTildeInPath
  }
}
