import TOMLKit

/// Returns the resolved app config from env, TOML, and defaults.
func resolvedAppConfig(from toml: TOMLTable) -> SharedAppRuntimeConfig {
  let appTable = toml["app"]?.table

  let widgetsPath =
    expandedPath(appTable?["widgets_dir"]?.string)
    ?? SharedPathDefaults.defaultWidgetsPath().path

  let lockDirectory =
    expandedEnvironmentPath(named: SharedEnvironmentKeys.lockDirectory)
    ?? expandedPath(appTable?["lock_dir"]?.string)
    ?? defaultSingleInstanceLockDirectoryPath()

  let widgetEditorStubPath =
    expandedPath(appTable?["widget_editor_stub_path"]?.string)
    ?? SharedPathDefaults.defaultWidgetEditorStubPath().path

  return SharedAppRuntimeConfig(
    widgetsPath: widgetsPath,
    lockDirectory: lockDirectory,
    widgetEditorStubPath: widgetEditorStubPath
  )
}

/// Returns the default directory used for single-instance lock files.
func defaultSingleInstanceLockDirectoryPath() -> String { return "/tmp/EasyBar" }
