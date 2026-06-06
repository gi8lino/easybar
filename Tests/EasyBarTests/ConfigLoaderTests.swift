import Darwin
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class ConfigLoaderTests: XCTestCase {
  private let environmentKeys = [
    SharedEnvironmentKeys.configPath,
    SharedEnvironmentKeys.loggingLevel,
  ]

  private var originalEnvironment: [String: String?] = [:]
  private var originalSnapshot: ConfigSnapshot!
  private var tempDirectoryURL: URL!

  /// Prepares isolated state before each test.
  override func setUpWithError() throws {
    try super.setUpWithError()

    let config = Config.makeUnloadedConfig()
    originalSnapshot = config.snapshot()
    originalEnvironment = environmentKeys.reduce(into: [:]) { result, key in
      result[key] = ProcessInfo.processInfo.environment[key]
    }

    tempDirectoryURL = try makeTemporaryDirectory()
    try copyThemeFixtures(
      to: tempDirectoryURL.appendingPathComponent("themes", isDirectory: true)
    )
  }

  /// Restores state mutated by the test fixture.
  override func tearDownWithError() throws {
    restoreEnvironment()

    let config = Config.makeUnloadedConfig()
    config.apply(originalSnapshot)
    config.resetRegisteredDirectories()

    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  /// Verifies that reload uses the config path environment override.
  func testReloadUsesConfigPathEnvironmentOverride() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("env-config.toml")
    let widgetsDirectory = tempDirectoryURL.appendingPathComponent("widgets").path
    let lockDirectory = tempDirectoryURL.appendingPathComponent("locks").path
    let loggingDirectory = tempDirectoryURL.appendingPathComponent("logs").path
    let runtimeDirectory = tempDirectoryURL.appendingPathComponent("runtime").path
    let luaSocketPath = URL(fileURLWithPath: runtimeDirectory)
      .appendingPathComponent("lua.sock")
      .path
    let calendarSocketPath = URL(fileURLWithPath: runtimeDirectory)
      .appendingPathComponent("calendar.sock")
      .path
    let networkSocketPath = URL(fileURLWithPath: runtimeDirectory)
      .appendingPathComponent("network.sock")
      .path

    try writeConfig(
      """
      [app]
      widgets_dir = "\(tomlEscaped(widgetsDirectory))"
      lock_dir = "\(tomlEscaped(lockDirectory))"
      lua_socket_path = "\(tomlEscaped(luaSocketPath))"

      [logging]
      directory = "\(tomlEscaped(loggingDirectory))"
      level = "error"

      [agents.calendar]
      socket_path = "\(tomlEscaped(calendarSocketPath))"

      [agents.network]
      socket_path = "\(tomlEscaped(networkSocketPath))"
      refresh_interval_seconds = 42.5
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.configPath, configFileURL.path)
    XCTAssertEqual(config.widgetsPath, widgetsDirectory)
    XCTAssertEqual(config.lockDirectory, lockDirectory)
    XCTAssertEqual(config.loggingDirectory, loggingDirectory)
    XCTAssertEqual(config.loggingLevel, .error)
    XCTAssertEqual(config.luaSocketPath, luaSocketPath)
    XCTAssertEqual(config.calendarAgentSocketPath, calendarSocketPath)
    XCTAssertEqual(config.networkAgentSocketPath, networkSocketPath)
    XCTAssertEqual(config.networkAgentRefreshIntervalSeconds, 42.5)

    XCTAssertTrue(FileManager.default.fileExists(atPath: widgetsDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: lockDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: loggingDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeDirectory))
  }

  func testInitialLoadAppliesConfigFileOverridesExplicitly() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("initial-load.toml")

    try """
    [logging]
    level = "debug"

    [app]
    develop = true
    """.write(to: configFileURL, atomically: true, encoding: .utf8)

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.loadInitialState()

    XCTAssertNil(error)
    XCTAssertEqual(config.loggingLevel, .debug)
    XCTAssertTrue(config.develop)
    XCTAssertNil(config.loadFailureState)
  }

  func testInitialLoadCapturesFailureStateWithoutPrintingDuringInit() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-initial-load.toml")

    try """
    [logging]
    level = "definitely_not_a_level"
    """.write(to: configFileURL, atomically: true, encoding: .utf8)

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.loadInitialState()

    XCTAssertNotNil(error)
    XCTAssertEqual(config.loadFailureState?.context, .initialLoad)
  }

  func testReloadAppliesLuaCommandLimits() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("lua-command-limits.toml")

    try """
    [app.lua_commands]
    timeout_seconds = 2.5
    max_output_bytes = 2048
    max_async_jobs = 3
    """.write(to: configFileURL, atomically: true, encoding: .utf8)

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.luaCommandTimeoutSeconds, 2.5)
    XCTAssertEqual(config.luaCommandMaxOutputBytes, 2048)
    XCTAssertEqual(config.luaCommandMaxAsyncJobs, 3)
  }

  func testReloadRejectsNonPositiveLuaCommandTimeout() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-lua-command-timeout.toml")

    try """
    [app.lua_commands]
    timeout_seconds = 0
    """.write(to: configFileURL, atomically: true, encoding: .utf8)

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard case .invalidValue(let path, let message)? = error as? ConfigError else {
      return XCTFail("Expected invalidValue ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "app.lua_commands.timeout_seconds")
    XCTAssertEqual(message, "expected a value greater than 0")
  }

  /// Verifies that bootstrap theme palette stays aligned with bundled default theme.
  func testBootstrapThemePaletteMatchesBundledDefaultTheme() throws {
    let config = Config.makeUnloadedConfig()
    config.resetToDefaults()
    let repoRootURL = repoRootURL()
    let bundledThemeURL =
      repoRootURL
      .appendingPathComponent("themes/default.toml")

    let themeText = try String(contentsOf: bundledThemeURL, encoding: .utf8)
    let expectedColors: [ThemeColorToken: String] = [
      .background: "#111111",
      .surface: "#1a1a1a",
      .surfaceElevated: "#2b2b2b",
      .surfaceHover: "#202020",
      .text: "#ffffff",
      .textSecondary: "#d0d0d0",
      .textTertiary: "#c0c0c0",
      .muted: "#6c7086",
      .mutedSecondary: "#8a8a8a",
      .outsideMonth: "#6e738d",
      .accent: "#91d7e3",
      .accentSecondary: "#89B4FA",
      .accentSoft: "#8bd5ca",
      .success: "#a6e3a1",
      .successSecondary: "#a6da95",
      .warning: "#f9e2af",
      .orange: "#fab387",
      .error: "#f38ba8",
      .danger: "#FF0000",
      .border: "#333333",
      .borderStrong: "#444444",
      .borderSubtle: "#00000000",
      .selectionText: "#0B1020",
      .selectionBackground: "#89B4FA",
      .transparent: "#00000000",
      .overlayOutline: "#000000F0",
      .overlayText: "#FFFFFFFF",
      .todayButtonBorder: "#3F2F6B",
    ]

    XCTAssertEqual(config.themeName, "default")

    for (token, value) in expectedColors {
      XCTAssertTrue(themeText.contains("\(token.rawValue) = \"\(value)\""))
      XCTAssertEqual(config.themeColors[token], value)
    }
  }

  /// Verifies that theme token table stays in sync with theme color accessors.
  func testThemeTokenTableStaysInSyncWithThemeColorAccessors() {
    let config = Config.makeUnloadedConfig()
    config.resetToDefaults()

    let expectedNames = Set(config.themeColors.valuesByName.keys)
    let actualNames = Set(ThemeColorToken.allCases.map(\.rawValue))

    XCTAssertEqual(actualNames, expectedNames)

    for token in ThemeColorToken.allCases {
      XCTAssertEqual(config.themeColorHex(named: token.rawValue), config.themeColors[token])
      XCTAssertEqual(config.resolveThemeColorHex(token.reference), config.themeColors[token])
    }
  }

  /// Verifies that Lua theme environment exports resolved colors without duplicate refs.
  func testLuaThemeEnvironmentExportsResolvedColorsWithoutDuplicateRefs() throws {
    let config = Config.makeUnloadedConfig()
    config.resetToDefaults()

    let environment = config.luaThemeEnvironment()
    let payloadJSON = try XCTUnwrap(environment[Config.luaThemeEnvironmentKey])
    let data = try XCTUnwrap(payloadJSON.data(using: .utf8))
    let payload = try XCTUnwrap(
      JSONSerialization.jsonObject(with: data) as? [String: Any]
    )

    XCTAssertEqual(payload["name"] as? String, config.themeName)
    XCTAssertNil(payload["ref"])

    let colors = try XCTUnwrap(payload["colors"] as? [String: String])

    for token in ThemeColorToken.allCases {
      XCTAssertEqual(colors[token.rawValue], config.themeColors[token])
    }
  }

  /// Verifies that bundled themes define the full rich theme palette.
  func testBundledThemesDefineEveryRichThemeToken() throws {
    let themesDirectoryURL = repoRootURL().appendingPathComponent("themes")
    let bundledThemeNames = ["default", "tokyo-night"]

    for themeName in bundledThemeNames {
      let themeText = try String(
        contentsOf: themesDirectoryURL.appendingPathComponent("\(themeName).toml"),
        encoding: .utf8
      )

      for token in ThemeColorToken.allCases {
        XCTAssertTrue(
          themeText.contains("\(token.rawValue) = \""),
          "missing \(token.rawValue) in \(themeName).toml"
        )
      }
    }
  }

  /// Verifies that reload applies config file overrides and creates required directories.
  func testReloadAppliesConfigFileOverridesAndCreatesRequiredDirectories() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("config.toml")
    let widgetsDirectory = tempDirectoryURL.appendingPathComponent("widgets").path
    let lockDirectory = tempDirectoryURL.appendingPathComponent("locks").path
    let loggingDirectory = tempDirectoryURL.appendingPathComponent("logs").path
    let runtimeDirectory = tempDirectoryURL.appendingPathComponent("runtime").path
    let luaSocketPath = URL(fileURLWithPath: runtimeDirectory)
      .appendingPathComponent("lua.sock")
      .path
    let widgetEditorStubPath = tempDirectoryURL.appendingPathComponent("generated/api.lua").path
    let calendarSocketPath = URL(fileURLWithPath: runtimeDirectory)
      .appendingPathComponent("calendar.sock")
      .path
    let networkSocketPath = URL(fileURLWithPath: runtimeDirectory)
      .appendingPathComponent("network.sock")
      .path

    try writeConfig(
      """
      [app]
      widgets_dir = "\(widgetsDirectory)"
      lua_path = "/usr/local/bin/lua"
      lua_socket_path = "\(luaSocketPath)"
      watch_config = false
      lock_dir = "\(lockDirectory)"
      widget_editor_stub_path = "\(widgetEditorStubPath)"
      develop = true

      [app.env]
      PATH = "/custom/bin"
      FOO = "bar"

      [logging]
      enabled = true
      level = "debug"
      directory = "\(loggingDirectory)"

      [agents.calendar]
      enabled = false
      socket_path = "\(calendarSocketPath)"

      [agents.network]
      enabled = false
      socket_path = "\(networkSocketPath)"
      refresh_interval_seconds = 15
      allow_unauthorized_non_sensitive_fields = true

      [bar]
      height = 40
      padding_x = 22
      extend_behind_notch = false

      [bar.colors]
      background = "#123456"
      border = "#abcdef"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.widgetsPath, widgetsDirectory)
    XCTAssertEqual(config.luaPath, "/usr/local/bin/lua")
    XCTAssertEqual(config.luaSocketPath, luaSocketPath)
    XCTAssertFalse(config.watchConfigFile)
    XCTAssertEqual(config.lockDirectory, lockDirectory)
    XCTAssertEqual(config.widgetEditorStubPath, widgetEditorStubPath)
    XCTAssertTrue(config.develop)

    XCTAssertEqual(config.appSection.environment["PATH"], "/custom/bin")
    XCTAssertEqual(config.appSection.environment["FOO"], "bar")

    XCTAssertTrue(config.loggingEnabled)
    XCTAssertEqual(config.loggingLevel, .debug)
    XCTAssertEqual(config.loggingDirectory, loggingDirectory)

    XCTAssertFalse(config.calendarAgentEnabled)
    XCTAssertEqual(config.calendarAgentSocketPath, calendarSocketPath)
    XCTAssertFalse(config.networkAgentEnabled)
    XCTAssertEqual(config.networkAgentSocketPath, networkSocketPath)
    XCTAssertEqual(config.networkAgentRefreshIntervalSeconds, 15)
    XCTAssertTrue(config.networkAgentAllowUnauthorizedNonSensitiveFields)

    XCTAssertEqual(config.barHeight, 40)
    XCTAssertEqual(config.barPaddingX, 22)
    XCTAssertFalse(config.barExtendBehindNotch)
    XCTAssertEqual(config.barBackgroundHex, "#123456")
    XCTAssertEqual(config.barBorderHex, "#abcdef")

    XCTAssertTrue(FileManager.default.fileExists(atPath: widgetsDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: lockDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: loggingDirectory))
    XCTAssertTrue(
      FileManager.default.fileExists(
        atPath: URL(fileURLWithPath: widgetEditorStubPath).deletingLastPathComponent().path
      )
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeDirectory))
  }

  func testReloadRejectsNegativeNetworkAgentRefreshInterval() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent(
      "negative-network-refresh-interval.toml"
    )

    try writeConfig(
      """
      [agents.network]
      refresh_interval_seconds = -1
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard case .invalidValue(let path, let message)? = error as? ConfigError else {
      return XCTFail("Expected invalidValue ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "agents.network.refresh_interval_seconds")
    XCTAssertEqual(message, "expected a value greater than or equal to 0")
  }

  /// Verifies that reload applies month popup agenda layout overrides.
  func testReloadAppliesMonthPopupAgendaLayoutOverride() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("calendar-layout.toml")

    try writeConfig(
      """
      [builtins.calendar]
      enabled = true

      [builtins.calendar.month.popup.agenda]
      layout = "appointments_calendar_vertical"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(
      config.builtinCalendar.month.popup.layout,
      .appointmentsCalendarVertical
    )
    XCTAssertEqual(
      config.builtinCalendar.calendarMonthPopupUIConfig.layout,
      .appointmentsCalendarVertical
    )
  }

  /// Verifies that reload returns config error for invalid logging level.
  func testReloadReturnsConfigErrorForInvalidLoggingLevel() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid.toml")

    try writeConfig(
      """
      [logging]
      level = "verbose"
      """,
      to: configFileURL
    )

    config.loggingLevel = .warn
    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard let configError = error as? ConfigError else {
      return XCTFail("Expected ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(configError.configPath, "logging.level")
    XCTAssertEqual(configError.detail, "expected one of debug, error, info, trace, warn")
    XCTAssertEqual(config.loggingLevel, .warn)
  }

  /// Verifies that reload failure keeps previous bar and builtin configuration.
  func testReloadFailureKeepsPreviousBarAndBuiltinConfiguration() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("reload-config.toml")

    try writeConfig(
      """
      [bar]
      height = 44

      [bar.colors]
      background = "#224466"

      [builtins.time]
      enabled = true
      position = "left"

      [builtins.time.content]
      format = "HH:mm:ss"

      [builtins.cpu]
      enabled = true

      [builtins.cpu.content]
      history_size = 24
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    XCTAssertNil(config.reload())

    XCTAssertEqual(config.barHeight, 44)
    XCTAssertEqual(config.barBackgroundHex, "#224466")
    XCTAssertTrue(config.builtinTime.enabled)
    XCTAssertEqual(config.builtinTime.position, .left)
    XCTAssertEqual(config.builtinTime.format, "HH:mm:ss")
    XCTAssertTrue(config.builtinCPU.enabled)
    XCTAssertEqual(config.builtinCPU.historySize, 24)

    try writeConfig(
      """
      [bar]
      height = 28

      [builtins.time]
      position = "sideways"
      """,
      to: configFileURL
    )

    let error = config.reload()

    guard let configError = error as? ConfigError else {
      return XCTFail("Expected ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(configError.configPath, "builtins.time.position")
    XCTAssertEqual(config.barHeight, 44)
    XCTAssertEqual(config.barBackgroundHex, "#224466")
    XCTAssertTrue(config.builtinTime.enabled)
    XCTAssertEqual(config.builtinTime.position, .left)
    XCTAssertEqual(config.builtinTime.format, "HH:mm:ss")
    XCTAssertTrue(config.builtinCPU.enabled)
    XCTAssertEqual(config.builtinCPU.historySize, 24)
  }

  /// Verifies that reload returns invalid type for bar height string value.
  func testReloadReturnsInvalidTypeForBarHeightStringValue() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-bar-type.toml")

    try writeConfig(
      """
      [bar]
      height = "tall"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard case .invalidType(let path, let expected, let actual)? = error as? ConfigError else {
      return XCTFail("Expected invalidType ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "bar.height")
    XCTAssertEqual(expected, "integer")
    XCTAssertEqual(actual, "string(tall)")
  }

  func testReloadRejectsNegativeBarHeight() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-bar-height.toml")

    try writeConfig(
      """
      [bar]
      height = -1
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard case .invalidValue(let path, let message)? = error as? ConfigError else {
      return XCTFail("Expected invalidValue ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "bar.height")
    XCTAssertEqual(message, "expected a value greater than or equal to 0")
  }

  func testReloadRejectsNegativeBarPaddingX() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-bar-padding.toml")

    try writeConfig(
      """
      [bar]
      padding_x = -1
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard case .invalidValue(let path, let message)? = error as? ConfigError else {
      return XCTFail("Expected invalidValue ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "bar.padding_x")
    XCTAssertEqual(message, "expected a value greater than or equal to 0")
  }

  /// Verifies that reload returns invalid type for logging enabled string value.
  func testReloadReturnsInvalidTypeForLoggingEnabledStringValue() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-logging-type.toml")

    try writeConfig(
      """
      [logging]
      enabled = "yes"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard case .invalidType(let path, let expected, let actual)? = error as? ConfigError else {
      return XCTFail("Expected invalidType ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "logging.enabled")
    XCTAssertEqual(expected, "bool")
    XCTAssertEqual(actual, "string(yes)")
  }

  /// Verifies that reload applies logging level from TOML.
  func testReloadAppliesLoggingLevelFromToml() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("logging-level.toml")

    try writeConfig(
      """
      [logging]
      level = "trace"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.loggingLevel, .trace)
  }

  /// Verifies that reload prefers the diagnostic log-level environment override over TOML.
  func testReloadPrefersEnvironmentLoggingLevelOverTomlValue() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("env-logging-level.toml")

    try writeConfig(
      """
      [logging]
      level = "info"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue("debug", for: SharedEnvironmentKeys.loggingLevel)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.loggingLevel, .debug)
  }

  /// Verifies that validate does not create directories for valid staged config.
  func testValidateDoesNotCreateDirectories() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("validate-only.toml")
    let widgetsDirectory = tempDirectoryURL.appendingPathComponent("widgets-only").path
    let lockDirectory = tempDirectoryURL.appendingPathComponent("locks-only").path
    let loggingDirectory = tempDirectoryURL.appendingPathComponent("logs-only").path

    try writeConfig(
      """
      [app]
      widgets_dir = "\(widgetsDirectory)"
      lock_dir = "\(lockDirectory)"

      [logging]
      directory = "\(loggingDirectory)"
      level = "info"
      """,
      to: configFileURL
    )

    _ = try Config.validate(configPathOverride: configFileURL.path)

    XCTAssertFalse(FileManager.default.fileExists(atPath: widgetsDirectory))
    XCTAssertFalse(FileManager.default.fileExists(atPath: lockDirectory))
    XCTAssertFalse(FileManager.default.fileExists(atPath: loggingDirectory))
  }

  /// Verifies that validate prefers explicit config path over environment override.
  func testValidatePrefersExplicitConfigPathOverEnvironmentOverride() throws {
    let explicitConfigFileURL = tempDirectoryURL.appendingPathComponent("explicit-validate.toml")
    let environmentConfigFileURL = tempDirectoryURL.appendingPathComponent("environment-validate.toml")

    try writeConfig(
      """
      [logging]
      level = "debug"
      """,
      to: explicitConfigFileURL
    )

    try writeConfig(
      """
      [logging]
      level = "definitely_not_a_level"
      """,
      to: environmentConfigFileURL
    )

    setEnvironmentValue(environmentConfigFileURL.path, for: SharedEnvironmentKeys.configPath)

    let loadedState = try Config.validate(configPathOverride: explicitConfigFileURL.path)

    XCTAssertEqual(loadedState.snapshot.logging.level, .debug)
  }

  /// Verifies that reload expands tilde paths from config file.
  func testReloadExpandsTildePathsFromConfigFile() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("tilde-paths.toml")
    let homePath = FileManager.default.homeDirectoryForCurrentUser.path

    try writeConfig(
      """
      [app]
      widgets_dir = "~/.config/easybar/widgets-test"
      lock_dir = "~/.cache/easybar-locks-test"

      [logging]
      directory = "~/.local/state/easybar-tests"

      [agents.calendar]
      socket_path = "~/.cache/easybar-tests/calendar.sock"

      [agents.network]
      socket_path = "~/.cache/easybar-tests/network.sock"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.widgetsPath, "\(homePath)/.config/easybar/widgets-test")
    XCTAssertEqual(config.lockDirectory, "\(homePath)/.cache/easybar-locks-test")
    XCTAssertEqual(config.loggingDirectory, "\(homePath)/.local/state/easybar-tests")
    XCTAssertEqual(config.calendarAgentSocketPath, "\(homePath)/.cache/easybar-tests/calendar.sock")
    XCTAssertEqual(config.networkAgentSocketPath, "\(homePath)/.cache/easybar-tests/network.sock")
  }

  /// Verifies that reload returns error when directory setting points to existing file.
  func testReloadReturnsErrorWhenDirectorySettingPointsToExistingFile() throws {
    let config = Config.makeUnloadedConfig()
    let blockingFileURL = tempDirectoryURL.appendingPathComponent("not-a-directory")
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-directory.toml")

    try "blocker".write(to: blockingFileURL, atomically: true, encoding: .utf8)
    try writeConfig(
      """
      [app]
      lock_dir = "\(blockingFileURL.path)"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard let configError = error as? ConfigError else {
      return XCTFail("Expected ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(configError.configPath, "app.lock_dir")
    XCTAssertEqual(
      configError.detail,
      "expected directory path, but found file at \(blockingFileURL.path)"
    )
  }

  /// Verifies that reload normalizes enum values with whitespace for builtins.
  func testReloadNormalizesEnumValuesWithWhitespaceForBuiltins() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("normalized-builtins.toml")

    try writeConfig(
      """
      [builtins.time]
      enabled = true
      position = " Left "
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertTrue(config.builtinTime.enabled)
    XCTAssertEqual(config.builtinTime.position, .left)
  }

  /// Verifies that reload applies Wi-Fi popup style from the canonical table.
  func testReloadAppliesWiFiPopupStyle() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("wifi-popup-style.toml")

    try writeConfig(
      """
      [builtins.wifi.popup]
      text_color = "#101010"
      background_color = "#202020"
      border_color = "#303030"
      border_width = 2
      corner_radius = 10
      padding_x = 12
      padding_y = 7
      margin_x = 3
      margin_y = 9
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.builtinWiFi.popup.textColorHex, "#101010")
    XCTAssertEqual(config.builtinWiFi.popup.backgroundColorHex, "#202020")
    XCTAssertEqual(config.builtinWiFi.popup.borderColorHex, "#303030")
    XCTAssertEqual(config.builtinWiFi.popup.borderWidth, 2)
    XCTAssertEqual(config.builtinWiFi.popup.cornerRadius, 10)
    XCTAssertEqual(config.builtinWiFi.popup.paddingX, 12)
    XCTAssertEqual(config.builtinWiFi.popup.paddingY, 7)
    XCTAssertEqual(config.builtinWiFi.popup.marginX, 3)
    XCTAssertEqual(config.builtinWiFi.popup.marginY, 9)
  }

  /// Verifies that reload returns error for unknown builtin group reference.
  func testReloadReturnsErrorForUnknownBuiltinGroupReference() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("unknown-group.toml")

    try writeConfig(
      """
      [builtins.groups.clock_row]
      enabled = true

      [builtins.time]
      enabled = true
      group = "missing"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard let configError = error as? ConfigError else {
      return XCTFail("Expected ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(configError.configPath, "builtins.time.group")
    XCTAssertEqual(
      configError.detail,
      "unknown built-in group 'missing'; expected one of clock_row"
    )
  }

  /// Verifies that reload returns error for nested builtin group reference.
  func testReloadReturnsErrorForNestedBuiltinGroupReference() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("nested-group.toml")

    try writeConfig(
      """
      [builtins.groups.outer]
      enabled = true

      [builtins.groups.inner]
      enabled = true
      group = "outer"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    guard let configError = error as? ConfigError else {
      return XCTFail("Expected ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(configError.configPath, "builtins.groups.inner.group")
    XCTAssertEqual(configError.detail, "built-in groups cannot be nested")
  }
}

extension ConfigLoaderTests {
  /// Creates an isolated temporary directory for file-system assertions.
  fileprivate func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-config-tests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    return directoryURL
  }

  /// Returns the repository root URL.
  fileprivate func repoRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }

  /// Copies bundled theme fixtures into a test-local themes directory.
  fileprivate func copyThemeFixtures(to destinationURL: URL) throws {
    let sourceURL = repoRootURL().appendingPathComponent("themes", isDirectory: true)

    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }

    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
  }

  /// Writes a TOML fixture to the current test config path.
  fileprivate func writeConfig(_ content: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Sets or clears one environment variable while preserving its original value.
  fileprivate func setEnvironmentValue(_ value: String?, for key: String) {
    if let value {
      setenv(key, value, 1)
    } else {
      unsetenv(key)
    }
  }

  /// Escapes a string so it can be embedded in a TOML basic string.
  fileprivate func tomlEscaped(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
  }

  /// Restores environment variables captured before the test.
  fileprivate func restoreEnvironment() {
    for key in environmentKeys {
      setEnvironmentValue(originalEnvironment[key] ?? nil, for: key)
    }
  }
}
