import TOMLKit

/// Returns the resolved app config from TOML and defaults.
func resolvedAppConfig(from toml: TOMLTable) -> SharedAppRuntimeConfig {
  let appTable = toml["app"]?.table

  let widgetsPath =
    expandedPath(appTable?["widgets_dir"]?.string)
    ?? SharedPathDefaults.defaultWidgetsPath().path

  let lockDirectory =
    expandedPath(appTable?["lock_dir"]?.string)
    ?? defaultSingleInstanceLockDirectoryPath()

  let luaSocketPath =
    expandedPath(appTable?["lua_socket_path"]?.string)
    ?? defaultLuaSocketPath()

  let widgetEditorStubPath =
    expandedPath(appTable?["widget_editor_stub_path"]?.string)
    ?? SharedPathDefaults.defaultWidgetEditorStubPath().path

  return SharedAppRuntimeConfig(
    widgetsPath: widgetsPath,
    lockDirectory: lockDirectory,
    luaSocketPath: luaSocketPath,
    widgetEditorStubPath: widgetEditorStubPath
  )
}

/// Returns the app defaults used before a config file has been parsed.
func resolvedAppEnvironmentDefaults() -> SharedAppRuntimeConfig {
  SharedAppRuntimeConfig(
    widgetsPath: SharedPathDefaults.defaultWidgetsPath().path,
    lockDirectory: defaultSingleInstanceLockDirectoryPath(),
    luaSocketPath: defaultLuaSocketPath(),
    widgetEditorStubPath: SharedPathDefaults.defaultWidgetEditorStubPath().path
  )
}

/// Returns the default directory used for single-instance lock files.
func defaultSingleInstanceLockDirectoryPath() -> String { return "/tmp/EasyBar" }

/// Returns the default Unix socket path used by the Lua runtime transport.
func defaultLuaSocketPath() -> String { return "/tmp/EasyBar/lua-runtime.sock" }
