import TOMLKit

/// Returns the resolved logging config from env, TOML, and defaults.
func resolvedLoggingConfig(from toml: TOMLTable) -> SharedLoggingRuntimeConfig {
  let loggingTable = toml["logging"]?.table

  let enabled =
    boolEnvironmentValue(named: "EASYBAR_LOGGING_ENABLED")
    ?? loggingTable?["enabled"]?.bool
    ?? false

  let level =
    ProcessLogLevel.normalized(stringEnvironmentValue(named: "EASYBAR_LOG_LEVEL"))
    ?? ProcessLogLevel.normalized(loggingTable?["level"]?.string)
    ?? .info

  let directory =
    expandedEnvironmentPath(named: "EASYBAR_LOGGING_DIRECTORY")
    ?? expandedPath(loggingTable?["directory"]?.string)
    ?? defaultLoggingDirectoryPath()

  return SharedLoggingRuntimeConfig(
    enabled: enabled,
    level: level,
    directory: directory
  )
}
