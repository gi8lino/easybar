import Foundation

/// Returns the resolved app config from TOML and defaults.
func resolvedAppConfig(from reader: SharedRuntimeConfigReader) throws -> SharedAppRuntimeConfig {
  let app = try reader.section("app")
  let configuredRuntimeDirectory = try app.expandedPath(
    "runtime_dir",
    fallback: SharedPathDefaults.defaultRuntimeDirectory().path
  )
  let runtimeDirectory = resolvedRuntimeDirectory(configuredPath: configuredRuntimeDirectory)

  return SharedAppRuntimeConfig(
    runtimeDirectory: runtimeDirectory,
    widgetsPath: try app.expandedPath(
      "widgets_dir",
      fallback: SharedPathDefaults.defaultWidgetsPath().path
    ),
    lockDirectory: try app.expandedPath(
      "lock_dir",
      fallback: runtimeDirectory
    ),
    luaSocketPath: try app.expandedPath(
      "lua_socket_path",
      fallback: SharedPathDefaults.luaSocketPath(in: runtimeDirectory)
    ),
    widgetEditorStubPath: try app.expandedPath(
      "widget_editor_stub_path",
      fallback: SharedPathDefaults.defaultWidgetEditorStubPath().path
    )
  )
}

/// Returns the app defaults used before a config file has been parsed.
func resolvedAppEnvironmentDefaults() -> SharedAppRuntimeConfig {
  let runtimeDirectory = resolvedRuntimeDirectory()

  return SharedAppRuntimeConfig(
    runtimeDirectory: runtimeDirectory,
    widgetsPath: SharedPathDefaults.defaultWidgetsPath().path,
    lockDirectory: runtimeDirectory,
    luaSocketPath: SharedPathDefaults.luaSocketPath(in: runtimeDirectory),
    widgetEditorStubPath: SharedPathDefaults.defaultWidgetEditorStubPath().path
  )
}
