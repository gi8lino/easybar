import TOMLKit

/// Returns the resolved logging config from env, TOML, and defaults.
func resolvedLoggingConfig(from toml: TOMLTable) -> SharedLoggingRuntimeConfig {
  let loggingTable = toml["logging"]?.table

  let enabled =
    boolEnvironmentValue(named: "EASYBAR_LOGGING_ENABLED")
    ?? loggingTable?["enabled"]?.bool
    ?? false

  let debugEnabled =
    boolEnvironmentValue(named: "EASYBAR_DEBUG")
    ?? loggingTable?["debug"]?.bool
    ?? false

  let traceEnabled =
    boolEnvironmentValue(named: "EASYBAR_TRACE")
    ?? loggingTable?["trace"]?.bool
    ?? false

  let directory =
    expandedEnvironmentPath(named: "EASYBAR_LOGGING_DIRECTORY")
    ?? expandedPath(loggingTable?["directory"]?.string)
    ?? defaultLoggingDirectoryPath()

  return SharedLoggingRuntimeConfig(
    enabled: enabled,
    debugEnabled: debugEnabled,
    traceEnabled: traceEnabled,
    directory: directory
  )
}
