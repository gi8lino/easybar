import Foundation
import TOMLKit

extension Config {

  /// Parses app-level settings, applies app-specific overrides, and registers directory requirements.
  func parseApp(from toml: TOMLTable) throws {
    let app = toml["app"]?.table ?? TOMLTable()

    let resolvedWidgetsPath =
      try optionalField(.expandedPath("widgets_dir"), from: app, path: "app", fallback: widgetsPath)
    widgetsPath = resolvedWidgetsPath

    luaPath =
      try optionalField(.string("lua_path"), from: app, path: "app", fallback: luaPath)

    let resolvedLuaSocketPath =
      try optionalField(.expandedPath("lua_socket_path"), from: app, path: "app", fallback: luaSocketPath)
    luaSocketPath = resolvedLuaSocketPath

    if let configuredEnvironment = try optionalField(
      .stringTable("env"),
      from: app,
      path: "app",
      fallback: nil
    ) {
      appSection.environment = Self.mergedAppEnvironment(with: configuredEnvironment)
    }

    watchConfigFile =
      try optionalField(.bool("watch_config"), from: app, path: "app", fallback: watchConfigFile)

    let resolvedLockDirectory =
      try optionalField(.expandedPath("lock_dir"), from: app, path: "app", fallback: lockDirectory)
    lockDirectory = resolvedLockDirectory

    let resolvedWidgetEditorStubPath =
      try optionalField(
        .expandedPath("widget_editor_stub_path"),
        from: app,
        path: "app",
        fallback: widgetEditorStubPath
      )
    widgetEditorStubPath = resolvedWidgetEditorStubPath

    develop =
      try optionalField(.bool("develop"), from: app, path: "app", fallback: develop)

    let luaCommands = app["lua_commands"]?.table ?? TOMLTable()
    luaCommandTimeoutSeconds =
      try optionalField(
        .number("timeout_seconds"),
        from: luaCommands,
        path: "app.lua_commands",
        fallback: luaCommandTimeoutSeconds
      )
    luaCommandMaxOutputBytes =
      try optionalField(
        .int("max_output_bytes"),
        from: luaCommands,
        path: "app.lua_commands",
        fallback: luaCommandMaxOutputBytes
      )
    luaCommandMaxAsyncJobs =
      try optionalField(
        .int("max_async_jobs"),
        from: luaCommands,
        path: "app.lua_commands",
        fallback: luaCommandMaxAsyncJobs
      )

    if luaCommandTimeoutSeconds <= 0 {
      throw ConfigError.invalidValue(
        path: "app.lua_commands.timeout_seconds",
        message: "expected a value greater than 0"
      )
    }

    if luaCommandMaxOutputBytes <= 0 {
      throw ConfigError.invalidValue(
        path: "app.lua_commands.max_output_bytes",
        message: "expected a value greater than 0"
      )
    }

    if luaCommandMaxAsyncJobs <= 0 {
      throw ConfigError.invalidValue(
        path: "app.lua_commands.max_async_jobs",
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
    let logging = toml["logging"]?.table ?? TOMLTable()

    loggingEnabled =
      try optionalField(.bool("enabled"), from: logging, path: "logging", fallback: loggingEnabled)

    if let configuredLevel = try optionalField(
      .string("level"),
      from: logging,
      path: "logging",
      fallback: nil
    ) {
      loggingLevel = try parseLogLevel(
        configuredLevel,
        path: "logging.level"
      )
    }

    if let envLevel = try environmentLogLevelOverride() {
      loggingLevel = envLevel
    }

    let resolvedLoggingDirectory =
      try optionalField(
        .expandedPath("directory"),
        from: logging,
        path: "logging",
        fallback: loggingDirectory
      )
    loggingDirectory = resolvedLoggingDirectory

    registerDirectoryRequirement(
      for: "logging.directory",
      path: resolvedLoggingDirectory,
      kind: .directory
    )
  }

  /// Parses agent settings, applies agent-specific overrides, and registers directory requirements.
  func parseAgents(from toml: TOMLTable) throws {
    let agents = toml["agents"]?.table ?? TOMLTable()

    let calendar = agents["calendar"]?.table ?? TOMLTable()
    calendarAgentEnabled =
      try optionalField(
        .bool("enabled"),
        from: calendar,
        path: "agents.calendar",
        fallback: calendarAgentEnabled
      )

    let resolvedCalendarSocketPath =
      try optionalField(
        .expandedPath("socket_path"),
        from: calendar,
        path: "agents.calendar",
        fallback: calendarAgentSocketPath
      )
    calendarAgentSocketPath = resolvedCalendarSocketPath

    registerDirectoryRequirement(
      for: "agents.calendar.socket_path",
      path: resolvedCalendarSocketPath,
      kind: .parentDirectory
    )

    let network = agents["network"]?.table ?? TOMLTable()
    networkAgentEnabled =
      try optionalField(
        .bool("enabled"),
        from: network,
        path: "agents.network",
        fallback: networkAgentEnabled
      )

    let resolvedNetworkSocketPath =
      try optionalField(
        .expandedPath("socket_path"),
        from: network,
        path: "agents.network",
        fallback: networkAgentSocketPath
      )
    networkAgentSocketPath = resolvedNetworkSocketPath

    networkAgentRefreshIntervalSeconds =
      try optionalField(
        .number("refresh_interval_seconds"),
        from: network,
        path: "agents.network",
        fallback: networkAgentRefreshIntervalSeconds
      )

    if networkAgentRefreshIntervalSeconds < 0 {
      throw ConfigError.invalidValue(
        path: "agents.network.refresh_interval_seconds",
        message: "expected a value greater than or equal to 0"
      )
    }

    networkAgentAllowUnauthorizedNonSensitiveFields =
      try optionalField(
        .bool("allow_unauthorized_non_sensitive_fields"),
        from: network,
        path: "agents.network",
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
    guard let bar = toml["bar"]?.table else { return }

    if let height = try optionalField(.int("height"), from: bar, path: "bar", fallback: nil) {
      guard height >= 0 else {
        throw ConfigError.invalidValue(
          path: "bar.height",
          message: "expected a value greater than or equal to 0"
        )
      }

      barHeight = CGFloat(height)
    }

    if let paddingX = try optionalField(.int("padding_x"), from: bar, path: "bar", fallback: nil) {
      guard paddingX >= 0 else {
        throw ConfigError.invalidValue(
          path: "bar.padding_x",
          message: "expected a value greater than or equal to 0"
        )
      }

      barPaddingX = CGFloat(paddingX)
    }

    barExtendBehindNotch =
      try optionalField(
        .bool("extend_behind_notch"),
        from: bar,
        path: "bar",
        fallback: barExtendBehindNotch
      )

    guard let colors = bar["colors"]?.table else { return }

    barBackgroundHex =
      try optionalField(.string("background"), from: colors, path: "bar.colors", fallback: barBackgroundHex)

    barBorderHex =
      try optionalField(.string("border"), from: colors, path: "bar.colors", fallback: barBorderHex)
  }
}
