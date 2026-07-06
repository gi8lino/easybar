import Foundation

extension SharedRuntimeConfig {
  /// Resolves the shared logging config from TOML, defaults, and the log-level override.
  static func resolvedLoggingConfig(
    from reader: SharedRuntimeConfigReader
  ) throws -> SharedLoggingRuntimeConfig {
    let logging = try reader.section("logging")

    return SharedLoggingRuntimeConfig(
      enabled: try logging.bool("enabled", fallback: false),
      level: try resolvedLoggingLevel(
        tomlValue: try logging.optionalString("level"),
        tomlPath: logging.path(for: "level"),
        fallback: .info
      ),
      directory: try logging.expandedPath(
        "directory",
        fallback: SharedPathDefaults.defaultLoggingDirectory().path
      )
    )
  }

  /// Resolves the shared logging defaults used before a config file has been parsed.
  static func resolvedLoggingEnvironmentDefaults() -> SharedLoggingRuntimeConfig {
    SharedLoggingRuntimeConfig(
      enabled: false,
      level: resolvedEnvironmentLoggingLevel(fallback: .info),
      directory: SharedPathDefaults.defaultLoggingDirectory().path
    )
  }

  /// Resolves the configured minimum logging level from the diagnostic override or TOML.
  private static func resolvedLoggingLevel(
    tomlValue: String?,
    tomlPath: String,
    fallback: ProcessLogLevel
  ) throws -> ProcessLogLevel {
    let configuredLevel: ProcessLogLevel

    if let tomlValue {
      guard let level = ProcessLogLevel.normalized(tomlValue) else {
        throw SharedRuntimeConfigError.invalidValue(
          path: tomlPath,
          message: "expected one of trace, debug, info, warn, error"
        )
      }

      configuredLevel = level
    } else {
      configuredLevel = fallback
    }

    return resolvedEnvironmentLoggingLevel(fallback: configuredLevel)
  }

  /// Resolves the diagnostic environment override or returns the fallback.
  private static func resolvedEnvironmentLoggingLevel(
    fallback: ProcessLogLevel
  ) -> ProcessLogLevel {
    guard let raw = stringEnvironmentValue(named: SharedEnvironmentKeys.loggingLevel) else {
      return fallback
    }

    return ProcessLogLevel.normalized(raw) ?? fallback
  }
}
