import TOMLKit

/// Returns the resolved app config from env, TOML, and defaults.
func resolvedAppConfig(from toml: TOMLTable) -> SharedAppRuntimeConfig {
  let appTable = toml["app"]?.table

  let widgetsPath =
    expandedPath(appTable?["widgets_dir"]?.string)
    ?? SharedPathDefaults.defaultWidgetsPath()

  let lockDirectory =
    expandedEnvironmentPath(named: SharedEnvironmentKeys.lockDirectory)
    ?? expandedPath(appTable?["lock_dir"]?.string)
    ?? defaultSingleInstanceLockDirectoryPath()

  return SharedAppRuntimeConfig(
    widgetsPath: widgetsPath,
    lockDirectory: lockDirectory
  )
}

/// Returns the default directory used for single-instance lock files.
func defaultSingleInstanceLockDirectoryPath() -> String {
  "/tmp/EasyBar"
}
