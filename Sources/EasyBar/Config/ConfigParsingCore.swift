import Foundation
import TOMLKit

extension Config {

  /// Parses app-level settings.
  func parseApp(from toml: TOMLTable) throws {
    guard let app = toml["app"]?.table else { return }

    widgetsPath =
      try optionalExpandedPath(app["widgets_dir"], path: "app.widgets_dir")
      ?? widgetsPath

    luaPath =
      try optionalString(app["lua_path"], path: "app.lua_path")
      ?? luaPath

    if let configuredEnvironment = try optionalStringTable(app["env"], path: "app.env") {
      appSection.environment = Self.mergedAppEnvironment(with: configuredEnvironment)
    }

    watchConfigFile =
      try optionalBool(app["watch_config"], path: "app.watch_config")
      ?? watchConfigFile

    lockDirectory =
      try optionalExpandedPath(app["lock_dir"], path: "app.lock_dir")
      ?? lockDirectory
  }

  /// Parses logging settings.
  func parseLogging(from toml: TOMLTable) throws {
    guard let logging = toml["logging"]?.table else { return }

    loggingEnabled =
      try optionalBool(logging["enabled"], path: "logging.enabled")
      ?? loggingEnabled

    if let configuredLevel = try optionalString(logging["level"], path: "logging.level") {
      loggingLevel = normalizedLogLevel(configuredLevel)
    } else if let legacyLevel = legacyConfigLogLevel(from: logging) {
      loggingLevel = legacyLevel
    }

    if let envLevel = environmentLogLevelOverride() {
      loggingLevel = envLevel
    }

    loggingDirectory =
      try optionalExpandedPath(logging["directory"], path: "logging.directory")
      ?? loggingDirectory
  }

  /// Parses agent settings.
  func parseAgents(from toml: TOMLTable) throws {
    guard let agents = toml["agents"]?.table else { return }

    if let calendar = agents["calendar"]?.table {
      calendarAgentEnabled =
        try optionalBool(calendar["enabled"], path: "agents.calendar.enabled")
        ?? calendarAgentEnabled

      calendarAgentSocketPath =
        try optionalExpandedPath(calendar["socket_path"], path: "agents.calendar.socket_path")
        ?? calendarAgentSocketPath
    }

    if let network = agents["network"]?.table {
      networkAgentEnabled =
        try optionalBool(network["enabled"], path: "agents.network.enabled")
        ?? networkAgentEnabled

      networkAgentSocketPath =
        try optionalExpandedPath(network["socket_path"], path: "agents.network.socket_path")
        ?? networkAgentSocketPath

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
    }
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
