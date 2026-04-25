import TOMLKit

extension SharedRuntimeConfig {
  /// Resolves the shared logging config from TOML plus supported environment overrides.
  static func resolvedLoggingConfig(from toml: TOMLTable) -> SharedLoggingRuntimeConfig {
    let loggingTable = toml["logging"]?.table

    let enabled =
      boolEnvironmentValue(named: SharedEnvironmentKeys.loggingEnabled)
      ?? loggingTable?["enabled"]?.bool
      ?? false

    let level = resolvedLoggingLevel(
      tomlValue: loggingTable?["level"]?.string,
      legacyDebugValue: loggingTable?["debug"]?.bool,
      environmentName: SharedEnvironmentKeys.loggingLevel,
      fallback: .info
    )

    let directory =
      expandedEnvironmentPath(named: SharedEnvironmentKeys.loggingDirectory)
      ?? expandedPath(loggingTable?["directory"]?.string)
      ?? SharedPathDefaults.defaultLoggingDirectory().path

    return SharedLoggingRuntimeConfig(
      enabled: enabled,
      level: level,
      directory: directory
    )
  }

  /// Resolves the configured minimum logging level from environment or TOML.
  private static func resolvedLoggingLevel(
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
}
