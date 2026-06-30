import AppKit
import EasyBarShared
import Foundation

/// Logs one-time startup diagnostics for support and troubleshooting.
@MainActor
struct AppStartupDiagnostics {
  private let logger: ProcessLogger

  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Logs one startup snapshot so service-vs-local differences are visible.
  func logStartup(services: AppServices) {
    logProcessStartup(
      processName: "easybar",
      configPath: services.config.configPath,
      socketPath: SharedRuntimeConfig.current.easyBarSocketPath,
      logger: logger
    )

    logConfigDetails(services: services)
    logScreenDetails()
    logEnvironmentDetails()
    logConfiguredEnvironment(services: services)
  }

  /// Logs whether required custom fonts are available at runtime.
  func validateRequiredFonts() {
    validateFont(named: "Symbols Nerd Font Mono")
  }

  /// Logs config-derived startup details.
  private func logConfigDetails(services: AppServices) {
    logger.info("config details", .field("widgets_path", services.config.widgetsPath))
    logger.info("config details", .field("lua_path", services.config.luaPath))
    logger.info("config details", .field("lua_socket_path", services.config.luaSocketPath))
    logger.info("config details", .field("watch_config", services.config.watchConfigFile))
    logger.info(
      "config details",
      .field("calendar_agent_enabled", services.config.calendarAgentEnabled),
      .field("socket", services.config.calendarAgentSocketPath)
    )
    logger.info(
      "config details",
      .field("network_agent_enabled", services.config.networkAgentEnabled),
      .field("socket", services.config.networkAgentSocketPath),
      .field("refresh_interval_seconds", services.config.networkAgentRefreshIntervalSeconds)
    )
    logger.info(
      "config details",
      .field("calendar_builtin_enabled", services.config.builtinCalendar.enabled),
      .field("popup_mode", services.config.builtinCalendar.popupMode.rawValue),
      .field("anchor_layout", services.config.builtinCalendar.anchor.layout.rawValue),
      .field("position", services.config.builtinCalendar.position.rawValue)
    )
    logger.info(
      "config details",
      .field("wifi_builtin_enabled", services.config.builtinWiFi.enabled),
      .field("position", services.config.builtinWiFi.position.rawValue)
    )
    logger.info(
      "config details",
      .field("bar_height", services.config.barHeight),
      .field("padding_x", services.config.barPaddingX),
      .field("extend_behind_notch", services.config.barExtendBehindNotch)
    )
  }

  /// Logs screen geometry visible at startup.
  private func logScreenDetails() {
    if let screen = NSScreen.main ?? NSScreen.screens.first {
      logger.info(
        "screen details",
        .field("screen_frame", NSStringFromRect(screen.frame)),
        .field("visible", NSStringFromRect(screen.visibleFrame))
      )
    } else {
      logger.warn("no screen available during startup logging")
    }
  }

  /// Logs relevant process environment override keys without exposing values.
  private func logEnvironmentDetails() {
    let env = ProcessInfo.processInfo.environment
    let configOverride = env[SharedEnvironmentKeys.configPath] ?? ""
    let logLevelOverride = env[SharedEnvironmentKeys.loggingLevel] ?? ""

    logger.info(
      "environment override",
      .field("key", SharedEnvironmentKeys.configPath),
      .field("value_set", !configOverride.isEmpty)
    )
    logger.info(
      "environment override",
      .field("key", SharedEnvironmentKeys.loggingLevel),
      .field("value_set", !logLevelOverride.isEmpty)
    )
  }

  /// Logs the configured environment keys passed to the Lua runtime.
  private func logConfiguredEnvironment(services: AppServices) {
    let environment = services.config.appSection.environment

    guard !environment.isEmpty else {
      logger.info("app env", .field("key", "<empty>"), .field("value_set", false))
      return
    }

    for key in environment.keys.sorted() {
      let value = environment[key] ?? ""
      logger.info("app env", .field("key", key), .field("value_set", !value.isEmpty))
    }
  }

  /// Logs one warning when a required font is missing.
  private func validateFont(named fontName: String) {
    if NSFont(name: fontName, size: 12) != nil {
      logger.info("font available", .field("name", fontName))
      return
    }

    logger.warn(
      "font missing; Nerd Font icons may render incorrectly or be clipped",
      .field("name", fontName)
    )
  }
}
