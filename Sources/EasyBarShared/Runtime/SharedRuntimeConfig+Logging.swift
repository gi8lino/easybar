import TOMLKit

extension SharedRuntimeConfig {
  /// Resolves the shared logging config from TOML, defaults, and the log-level override.
  static func resolvedLoggingConfig(from toml: TOMLTable) -> SharedLoggingRuntimeConfig {
    let loggingTable = toml["logging"]?.table

    let enabled = loggingTable?["enabled"]?.bool ?? false

    let level = resolvedLoggingLevel(
      tomlValue: loggingTable?["level"]?.string,
      legacyDebugValue: loggingTable?["debug"]?.bool,
      fallback: .info
    )

    let directory =
      expandedPath(loggingTable?["directory"]?.string)
      ?? SharedPathDefaults.defaultLoggingDirectory().path

    return SharedLoggingRuntimeConfig(
      enabled: enabled,
      level: level,
      directory: directory
    )
  }

  /// Resolves the shared logging defaults used before a config file has been parsed.
  static func resolvedLoggingEnvironmentDefaults() -> SharedLoggingRuntimeConfig {
    SharedLoggingRuntimeConfig(
      enabled: false,
      level: resolvedLoggingLevel(
        tomlValue: nil,
        legacyDebugValue: nil,
        fallback: .info
      ),
      directory: SharedPathDefaults.defaultLoggingDirectory().path
    )
  }

  /// Resolves the configured minimum logging level from the diagnostic override or TOML.
  private static func resolvedLoggingLevel(
    tomlValue: String?,
    legacyDebugValue: Bool?,
    fallback: ProcessLogLevel
  ) -> ProcessLogLevel {
    if let raw = stringEnvironmentValue(named: SharedEnvironmentKeys.loggingLevel),
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
