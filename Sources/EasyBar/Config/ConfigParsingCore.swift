import Foundation
import TOMLKit

extension Config {

  /// Parses app-level settings, applies app-specific overrides, and registers directory requirements.
  func parseApp(from toml: TOMLTable) throws {
    let app = toml["app"]?.table ?? TOMLTable()

    let resolvedWidgetsPath =
      try optionalExpandedPath(app["widgets_dir"], path: "app.widgets_dir")
      ?? widgetsPath
    widgetsPath = resolvedWidgetsPath

    luaPath =
      try optionalString(app["lua_path"], path: "app.lua_path")
      ?? luaPath

    if let configuredEnvironment = try optionalStringTable(app["env"], path: "app.env") {
      appSection.environment = Self.mergedAppEnvironment(with: configuredEnvironment)
    }

    watchConfigFile =
      try optionalBool(app["watch_config"], path: "app.watch_config")
      ?? watchConfigFile

    let resolvedLockDirectory =
      try optionalExpandedPath(app["lock_dir"], path: "app.lock_dir")
      ?? lockDirectory
    lockDirectory = resolvedLockDirectory

    develop =
      try optionalBool(app["develop"], path: "app.develop")
      ?? develop

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
  }

  /// Parses logging settings, applies logging-specific overrides, and registers directory requirements.
  func parseLogging(from toml: TOMLTable) throws {
    let logging = toml["logging"]?.table ?? TOMLTable()

    loggingEnabled =
      try optionalBool(logging["enabled"], path: "logging.enabled")
      ?? loggingEnabled

    if let configuredLevel = try optionalString(logging["level"], path: "logging.level") {
      loggingLevel = try parseLogLevel(
        configuredLevel,
        path: "logging.level"
      )
    } else if let legacyLevel = legacyConfigLogLevel(from: logging) {
      loggingLevel = legacyLevel
    }

    if let envLevel = try environmentLogLevelOverride() {
      loggingLevel = envLevel
    }

    let resolvedLoggingDirectory =
      try optionalExpandedPath(logging["directory"], path: "logging.directory")
      ?? loggingDirectory
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
      try optionalBool(calendar["enabled"], path: "agents.calendar.enabled")
      ?? calendarAgentEnabled

    let resolvedCalendarSocketPath =
      try optionalExpandedPath(calendar["socket_path"], path: "agents.calendar.socket_path")
      ?? calendarAgentSocketPath
    calendarAgentSocketPath = resolvedCalendarSocketPath

    registerDirectoryRequirement(
      for: "agents.calendar.socket_path",
      path: resolvedCalendarSocketPath,
      kind: .parentDirectory
    )

    let network = agents["network"]?.table ?? TOMLTable()
    networkAgentEnabled =
      try optionalBool(network["enabled"], path: "agents.network.enabled")
      ?? networkAgentEnabled

    let resolvedNetworkSocketPath =
      try optionalExpandedPath(network["socket_path"], path: "agents.network.socket_path")
      ?? networkAgentSocketPath
    networkAgentSocketPath = resolvedNetworkSocketPath

    networkAgentRefreshIntervalSeconds =
      try optionalNumber(
        network["refresh_interval_seconds"],
        path: "agents.network.refresh_interval_seconds"
      ) ?? networkAgentRefreshIntervalSeconds

    networkAgentAllowUnauthorizedNonSensitiveFields =
      try optionalBool(
        network["allow_unauthorized_non_sensitive_fields"],
        path: "agents.network.allow_unauthorized_non_sensitive_fields"
      ) ?? networkAgentAllowUnauthorizedNonSensitiveFields

    registerDirectoryRequirement(
      for: "agents.network.socket_path",
      path: resolvedNetworkSocketPath,
      kind: .parentDirectory
    )
  }

  /// Parses bar-level settings.
  func parseBar(from toml: TOMLTable) throws {
    guard let bar = toml["bar"]?.table else { return }

    if let height = try optionalInt(bar["height"], path: "bar.height") {
      barHeight = CGFloat(height)
    }

    if let paddingX = try optionalInt(bar["padding_x"], path: "bar.padding_x") {
      barPaddingX = CGFloat(paddingX)
    }

    barExtendBehindNotch =
      try optionalBool(
        bar["extend_behind_notch"],
        path: "bar.extend_behind_notch"
      ) ?? barExtendBehindNotch

    guard let colors = bar["colors"]?.table else { return }

    barBackgroundHex =
      try optionalString(colors["background"], path: "bar.colors.background")
      ?? barBackgroundHex

    barBorderHex =
      try optionalString(colors["border"], path: "bar.colors.border")
      ?? barBorderHex
  }
}
