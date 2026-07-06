import Foundation

/// Returns the resolved app config from TOML and defaults.
func resolvedAppConfig(from reader: SharedRuntimeConfigReader) throws -> SharedAppRuntimeConfig {
  let app = try reader.section("app")

  return SharedAppRuntimeConfig(
    widgetsPath: try app.expandedPath(
      "widgets_dir",
      fallback: SharedPathDefaults.defaultWidgetsPath().path
    ),
    lockDirectory: try app.expandedPath(
      "lock_dir",
      fallback: defaultSingleInstanceLockDirectoryPath()
    ),
    luaSocketPath: try app.expandedPath(
      "lua_socket_path",
      fallback: defaultLuaSocketPath()
    ),
    widgetEditorStubPath: try app.expandedPath(
      "widget_editor_stub_path",
      fallback: SharedPathDefaults.defaultWidgetEditorStubPath().path
    )
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
