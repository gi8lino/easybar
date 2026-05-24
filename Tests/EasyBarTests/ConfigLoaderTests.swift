import Darwin
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class ConfigLoaderTests: XCTestCase {
  private let environmentKeys = [
    SharedEnvironmentKeys.configPath,
    SharedEnvironmentKeys.lockDirectory,
    SharedEnvironmentKeys.loggingDirectory,
    SharedEnvironmentKeys.loggingLevel,
    SharedEnvironmentKeys.luaSocketPath,
    SharedEnvironmentKeys.calendarAgentSocketPath,
    SharedEnvironmentKeys.networkAgentSocketPath,
    SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds,
  ]

  private var originalEnvironment: [String: String?] = [:]
  private var originalSnapshot: ConfigSnapshot!
  private var tempDirectoryURL: URL!

  /// Handles set up with error.
  override func setUpWithError() throws {
    try super.setUpWithError()

    let config = Config.shared
    originalSnapshot = config.snapshot()
    originalEnvironment = environmentKeys.reduce(into: [:]) { result, key in
      result[key] = ProcessInfo.processInfo.environment[key]
    }
    tempDirectoryURL = try makeTemporaryDirectory()
  }

  /// Handles tear down with error.
  override func tearDownWithError() throws {
    restoreEnvironment()

    let config = Config.shared
    config.apply(originalSnapshot)
    config.resetRegisteredDirectories()

    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  /// Handles test reload uses environment overrides when config file is missing.
  func testReloadUsesEnvironmentOverridesWhenConfigFileIsMissing() throws {
    let config = Config.shared
    let missingConfigPath = tempDirectoryURL.appendingPathComponent("missing.toml").path
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

    setEnvironmentValue(missingConfigPath, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue(lockDirectory, for: SharedEnvironmentKeys.lockDirectory)
    setEnvironmentValue(loggingDirectory, for: SharedEnvironmentKeys.loggingDirectory)
    setEnvironmentValue("error", for: SharedEnvironmentKeys.loggingLevel)
    setEnvironmentValue(luaSocketPath, for: SharedEnvironmentKeys.luaSocketPath)
    setEnvironmentValue(calendarSocketPath, for: SharedEnvironmentKeys.calendarAgentSocketPath)
    setEnvironmentValue(networkSocketPath, for: SharedEnvironmentKeys.networkAgentSocketPath)
    setEnvironmentValue("42.5", for: SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.configPath, missingConfigPath)
    XCTAssertEqual(config.widgetsPath, SharedPathDefaults.defaultWidgetsPath().path)
    XCTAssertEqual(config.lockDirectory, lockDirectory)
    XCTAssertEqual(config.loggingDirectory, loggingDirectory)
    XCTAssertEqual(config.loggingLevel, .error)
    XCTAssertEqual(config.luaSocketPath, luaSocketPath)
    XCTAssertEqual(config.calendarAgentSocketPath, calendarSocketPath)
    XCTAssertEqual(config.networkAgentSocketPath, networkSocketPath)
    XCTAssertEqual(config.networkAgentRefreshIntervalSeconds, 42.5)

    XCTAssertTrue(FileManager.default.fileExists(atPath: lockDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: loggingDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeDirectory))
    XCTAssertEqual(config.registeredDirectories["app.lock_dir"]?.path, lockDirectory)
    XCTAssertEqual(config.registeredDirectories["app.lua_socket_path"]?.path, luaSocketPath)
    XCTAssertEqual(config.registeredDirectories["logging.directory"]?.path, loggingDirectory)
  }

  /// Handles test reload applies config file overrides and creates required directories.
  func testReloadAppliesConfigFileOverridesAndCreatesRequiredDirectories() throws {
    let config = Config.shared
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

  /// Handles test reload applies month popup agenda layout overrides.
  func testReloadAppliesMonthPopupAgendaLayoutOverride() throws {
    let config = Config.shared
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

  /// Handles test reload returns config error for invalid logging level.
  func testReloadReturnsConfigErrorForInvalidLoggingLevel() throws {
    let config = Config.shared
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

  /// Handles test reload failure keeps previous bar and builtin configuration.
  func testReloadFailureKeepsPreviousBarAndBuiltinConfiguration() throws {
    let config = Config.shared
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

  /// Handles test reload returns invalid type for bar height string value.
  func testReloadReturnsInvalidTypeForBarHeightStringValue() throws {
    let config = Config.shared
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

  /// Handles test reload returns invalid type for logging enabled string value.
  func testReloadReturnsInvalidTypeForLoggingEnabledStringValue() throws {
    let config = Config.shared
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

  /// Handles test reload prefers environment logging level over toml value.
  func testReloadPrefersEnvironmentLoggingLevelOverTomlValue() throws {
    let config = Config.shared
    let configFileURL = tempDirectoryURL.appendingPathComponent("env-logging-precedence.toml")

    try writeConfig(
      """
      [logging]
      level = "info"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue("trace", for: SharedEnvironmentKeys.loggingLevel)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.loggingLevel, .trace)
  }

  /// Handles test reload uses legacy logging debug when level is absent.
  func testReloadUsesLegacyLoggingDebugWhenLevelIsAbsent() throws {
    let config = Config.shared
    let configFileURL = tempDirectoryURL.appendingPathComponent("legacy-logging.toml")

    try writeConfig(
      """
      [logging]
      debug = true
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = config.reload()

    XCTAssertNil(error)
    XCTAssertEqual(config.loggingLevel, .debug)
  }

  /// Handles test reload expands tilde paths from config file.
  func testReloadExpandsTildePathsFromConfigFile() throws {
    let config = Config.shared
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

  /// Handles test reload returns error when directory setting points to existing file.
  func testReloadReturnsErrorWhenDirectorySettingPointsToExistingFile() throws {
    let config = Config.shared
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

  /// Handles test reload normalizes enum values with whitespace for builtins.
  func testReloadNormalizesEnumValuesWithWhitespaceForBuiltins() throws {
    let config = Config.shared
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

  /// Handles test reload returns error for unknown builtin group reference.
  func testReloadReturnsErrorForUnknownBuiltinGroupReference() throws {
    let config = Config.shared
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

  /// Handles test reload returns error for nested builtin group reference.
  func testReloadReturnsErrorForNestedBuiltinGroupReference() throws {
    let config = Config.shared
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
  /// Creates temporary directory.
  fileprivate func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-config-tests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    return directoryURL
  }

  /// Handles write config.
  fileprivate func writeConfig(_ content: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  /// Handles set environment value.
  fileprivate func setEnvironmentValue(_ value: String?, for key: String) {
    if let value {
      setenv(key, value, 1)
    } else {
      unsetenv(key)
    }
  }

  /// Handles restore environment.
  fileprivate func restoreEnvironment() {
    for key in environmentKeys {
      setEnvironmentValue(originalEnvironment[key] ?? nil, for: key)
    }
  }
}
