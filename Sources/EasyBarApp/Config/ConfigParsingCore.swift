import Foundation
import TOMLKit

extension Config {

  /// Parses app-level settings, applies app-specific overrides, and registers directory requirements.
  func parseApp(from toml: TOMLTable) throws {
    let reader = configReader(table: toml, path: "")
    let app = try reader.section("app")

    let resolvedWidgetsPath = try app.expandedPath("widgets_dir", fallback: widgetsPath)
    widgetsPath = resolvedWidgetsPath

    luaPath = try app.string("lua_path", fallback: luaPath)

    let resolvedLuaSocketPath = try app.expandedPath("lua_socket_path", fallback: luaSocketPath)
    luaSocketPath = resolvedLuaSocketPath

    if let configuredEnvironment = try app.optionalStringTable("env") {
      appSection.environment = Self.mergedAppEnvironment(with: configuredEnvironment)
    }

    watchConfigFile = try app.bool("watch_config", fallback: watchConfigFile)

    let resolvedLockDirectory = try app.expandedPath("lock_dir", fallback: lockDirectory)
    lockDirectory = resolvedLockDirectory

    let resolvedWidgetEditorStubPath = try app.expandedPath(
      "widget_editor_stub_path",
      fallback: widgetEditorStubPath
    )
    widgetEditorStubPath = resolvedWidgetEditorStubPath

    develop = try app.bool("develop", fallback: develop)

    let luaCommands = try app.section("lua_commands")
    luaCommandTimeoutSeconds = try luaCommands.double(
      "timeout_seconds",
      fallback: luaCommandTimeoutSeconds
    )
    luaCommandMaxOutputBytes = try luaCommands.int(
      "max_output_bytes",
      fallback: luaCommandMaxOutputBytes
    )
    luaCommandMaxAsyncJobs = try luaCommands.int(
      "max_async_jobs",
      fallback: luaCommandMaxAsyncJobs
    )

    if luaCommandTimeoutSeconds <= 0 {
      throw ConfigError.invalidValue(
        path: luaCommands.path(for: "timeout_seconds"),
        message: "expected a value greater than 0"
      )
    }

    if luaCommandMaxOutputBytes <= 0 {
      throw ConfigError.invalidValue(
        path: luaCommands.path(for: "max_output_bytes"),
        message: "expected a value greater than 0"
      )
    }

    if luaCommandMaxAsyncJobs <= 0 {
      throw ConfigError.invalidValue(
        path: luaCommands.path(for: "max_async_jobs"),
        message: "expected a value greater than 0"
      )
    }

    registerDirectoryRequirement(
      for: "app.widgets_dir",
      path: resolvedWidgetsPath,
      kind: .directory
    )

    registerDirectoryRequirement(
      for: "app.lock_dir",
      path: resolvedLockDirectory,
      kind: .directory
    )

    registerDirectoryRequirement(
      for: "app.lua_socket_path",
      path: resolvedLuaSocketPath,
      kind: .parentDirectory
    )

    registerDirectoryRequirement(
      for: "app.widget_editor_stub_path",
      path: resolvedWidgetEditorStubPath,
      kind: .parentDirectory
    )
  }

  /// Parses logging settings, applies logging-specific overrides, and registers directory requirements.
  func parseLogging(from toml: TOMLTable) throws {
    let reader = configReader(table: toml, path: "")
    let logging = try reader.section("logging")

    loggingEnabled = try logging.bool("enabled", fallback: loggingEnabled)

    if let configuredLevel = try logging.optionalString("level") {
      loggingLevel = try parseLogLevel(
        configuredLevel,
        path: logging.path(for: "level")
      )
    }

    if let envLevel = try environmentLogLevelOverride() {
      loggingLevel = envLevel
    }

    let resolvedLoggingDirectory = try logging.expandedPath("directory", fallback: loggingDirectory)
    loggingDirectory = resolvedLoggingDirectory

    registerDirectoryRequirement(
      for: "logging.directory",
      path: resolvedLoggingDirectory,
      kind: .directory
    )
  }

  /// Parses agent settings, applies agent-specific overrides, and registers directory requirements.
  func parseAgents(from toml: TOMLTable) throws {
    let reader = configReader(table: toml, path: "")
    let agents = try reader.section("agents")
    let calendar = try agents.section("calendar")

    calendarAgentEnabled = try calendar.bool("enabled", fallback: calendarAgentEnabled)

    let resolvedCalendarSocketPath = try calendar.expandedPath(
      "socket_path",
      fallback: calendarAgentSocketPath
    )
    calendarAgentSocketPath = resolvedCalendarSocketPath

    registerDirectoryRequirement(
      for: "agents.calendar.socket_path",
      path: resolvedCalendarSocketPath,
      kind: .parentDirectory
    )

    let network = try agents.section("network")
    networkAgentEnabled = try network.bool("enabled", fallback: networkAgentEnabled)

    let resolvedNetworkSocketPath = try network.expandedPath(
      "socket_path",
      fallback: networkAgentSocketPath
    )
    networkAgentSocketPath = resolvedNetworkSocketPath

    networkAgentRefreshIntervalSeconds = try network.double(
      "refresh_interval_seconds",
      fallback: networkAgentRefreshIntervalSeconds
    )

    if networkAgentRefreshIntervalSeconds < 0 {
      throw ConfigError.invalidValue(
        path: network.path(for: "refresh_interval_seconds"),
        message: "expected a value greater than or equal to 0"
      )
    }

    networkAgentAllowUnauthorizedNonSensitiveFields = try network.bool(
      "allow_unauthorized_non_sensitive_fields",
      fallback: networkAgentAllowUnauthorizedNonSensitiveFields
    )

    registerDirectoryRequirement(
      for: "agents.network.socket_path",
      path: resolvedNetworkSocketPath,
      kind: .parentDirectory
    )
  }

  /// Parses bar-level settings.
  func parseBar(from toml: TOMLTable) throws {
    guard let bar = try configReader(table: toml, path: "").optionalSection("bar") else { return }

    if let height = try bar.optionalInt("height") {
      guard height >= 0 else {
        throw ConfigError.invalidValue(
          path: bar.path(for: "height"),
          message: "expected a value greater than or equal to 0"
        )
      }

      barHeight = CGFloat(height)
    }

    if let paddingX = try bar.optionalInt("padding_x") {
      guard paddingX >= 0 else {
        throw ConfigError.invalidValue(
          path: bar.path(for: "padding_x"),
          message: "expected a value greater than or equal to 0"
        )
      }

      barPaddingX = CGFloat(paddingX)
    }

    barExtendBehindNotch = try bar.bool("extend_behind_notch", fallback: barExtendBehindNotch)

    guard let colors = try bar.optionalSection("colors") else { return }

    barBackgroundHex = try colors.string("background", fallback: barBackgroundHex)
    barBorderHex = try colors.string("border", fallback: barBorderHex)
  }
}
