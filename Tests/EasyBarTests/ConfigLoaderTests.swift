import Darwin
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBar

final class ConfigLoaderTests: XCTestCase {
  private let environmentKeys = [
    SharedEnvironmentKeys.configPath,
    SharedEnvironmentKeys.lockDirectory,
    SharedEnvironmentKeys.loggingDirectory,
    SharedEnvironmentKeys.loggingLevel,
    SharedEnvironmentKeys.calendarAgentSocketPath,
    SharedEnvironmentKeys.networkAgentSocketPath,
    SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds,
  ]

  private var originalEnvironment: [String: String?] = [:]
  private var originalSnapshot: ConfigSnapshot!
  private var tempDirectoryURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()

    let config = Config.shared
    originalSnapshot = config.snapshot()
    originalEnvironment = environmentKeys.reduce(into: [:]) { result, key in
      result[key] = ProcessInfo.processInfo.environment[key]
    }
    tempDirectoryURL = try makeTemporaryDirectory()
  }

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

  func testReloadUsesEnvironmentOverridesWhenConfigFileIsMissing() throws {
    let config = Config.shared
    let missingConfigPath = tempDirectoryURL.appendingPathComponent("missing.toml").path
    let lockDirectory = tempDirectoryURL.appendingPathComponent("locks").path
    let loggingDirectory = tempDirectoryURL.appendingPathComponent("logs").path
    let runtimeDirectory = tempDirectoryURL.appendingPathComponent("runtime").path
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
    XCTAssertEqual(config.calendarAgentSocketPath, calendarSocketPath)
    XCTAssertEqual(config.networkAgentSocketPath, networkSocketPath)
    XCTAssertEqual(config.networkAgentRefreshIntervalSeconds, 42.5)

    XCTAssertTrue(FileManager.default.fileExists(atPath: lockDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: loggingDirectory))
    XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeDirectory))
    XCTAssertEqual(config.registeredDirectories["app.lock_dir"]?.path, lockDirectory)
    XCTAssertEqual(config.registeredDirectories["logging.directory"]?.path, loggingDirectory)
  }

  func testReloadAppliesConfigFileOverridesAndCreatesRequiredDirectories() throws {
    let config = Config.shared
    let configFileURL = tempDirectoryURL.appendingPathComponent("config.toml")
    let widgetsDirectory = tempDirectoryURL.appendingPathComponent("widgets").path
    let lockDirectory = tempDirectoryURL.appendingPathComponent("locks").path
    let loggingDirectory = tempDirectoryURL.appendingPathComponent("logs").path
    let runtimeDirectory = tempDirectoryURL.appendingPathComponent("runtime").path
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

    guard case let .invalidType(path, expected, actual)? = error as? ConfigError else {
      return XCTFail("Expected invalidType ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "bar.height")
    XCTAssertEqual(expected, "integer")
    XCTAssertEqual(actual, "string(tall)")
  }

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

    guard case let .invalidType(path, expected, actual)? = error as? ConfigError else {
      return XCTFail("Expected invalidType ConfigError, got \(String(describing: error))")
    }

    XCTAssertEqual(path, "logging.enabled")
    XCTAssertEqual(expected, "bool")
    XCTAssertEqual(actual, "string(yes)")
  }
}

extension ConfigLoaderTests {
  fileprivate func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-config-tests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    return directoryURL
  }

  fileprivate func writeConfig(_ content: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try content.write(to: url, atomically: true, encoding: .utf8)
  }

  fileprivate func setEnvironmentValue(_ value: String?, for key: String) {
    if let value {
      setenv(key, value, 1)
    } else {
      unsetenv(key)
    }
  }

  fileprivate func restoreEnvironment() {
    for key in environmentKeys {
      setEnvironmentValue(originalEnvironment[key] ?? nil, for: key)
    }
  }
}
