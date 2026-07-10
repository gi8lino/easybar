import Darwin
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class ConfigLoaderPathTests: ConfigLoaderTestCase {
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
      runtime_dir = "\(tomlEscaped(runtimeDirectory))"
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
    XCTAssertEqual(config.runtimeDirectory, runtimeDirectory)
    XCTAssertEqual(
      config.easyBarSocketPath,
      SharedPathDefaults.easyBarSocketPath(in: runtimeDirectory)
    )
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

  func testReloadDerivesRuntimePathsFromRuntimeDirectory() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("derived-runtime-paths.toml")
    let runtimeDirectory = tempDirectoryURL.appendingPathComponent("derived-runtime").path

    try writeConfig(
      """
      [app]
      runtime_dir = "\(tomlEscaped(runtimeDirectory))"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue(nil, for: SharedEnvironmentKeys.runtimeDirectory)

    XCTAssertNil(config.reload())
    XCTAssertEqual(config.runtimeDirectory, runtimeDirectory)
    XCTAssertEqual(config.lockDirectory, runtimeDirectory)
    XCTAssertEqual(
      config.luaSocketPath,
      SharedPathDefaults.luaSocketPath(in: runtimeDirectory)
    )
    XCTAssertEqual(
      config.calendarAgentSocketPath,
      SharedPathDefaults.calendarAgentSocketPath(in: runtimeDirectory)
    )
    XCTAssertEqual(
      config.networkAgentSocketPath,
      SharedPathDefaults.networkAgentSocketPath(in: runtimeDirectory)
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeDirectory))
  }

  func testReloadPrefersRuntimeDirectoryEnvironmentOverride() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-directory-env.toml")
    let configuredDirectory = tempDirectoryURL.appendingPathComponent("configured-runtime").path
    let environmentDirectory = tempDirectoryURL.appendingPathComponent("environment-runtime").path

    try writeConfig(
      """
      [app]
      runtime_dir = "\(tomlEscaped(configuredDirectory))"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue(environmentDirectory, for: SharedEnvironmentKeys.runtimeDirectory)

    XCTAssertNil(config.reload())
    XCTAssertEqual(config.runtimeDirectory, environmentDirectory)
    XCTAssertEqual(config.lockDirectory, environmentDirectory)
    XCTAssertEqual(
      config.luaSocketPath,
      SharedPathDefaults.luaSocketPath(in: environmentDirectory)
    )
    XCTAssertEqual(
      config.easyBarSocketPath,
      SharedPathDefaults.easyBarSocketPath(in: environmentDirectory)
    )
    XCTAssertEqual(
      config.calendarAgentSocketPath,
      SharedPathDefaults.calendarAgentSocketPath(in: environmentDirectory)
    )
    XCTAssertEqual(
      config.networkAgentSocketPath,
      SharedPathDefaults.networkAgentSocketPath(in: environmentDirectory)
    )
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
    let environmentConfigFileURL = tempDirectoryURL.appendingPathComponent(
      "environment-validate.toml")

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

  /// Verifies that parse errors include the nearest table path and failing key.
  func testParseFailureContextUsesNearestCommentedTableHeader() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-table-context.toml")

    try writeConfig(
      """
      [logging] # logging settings
      level = "debug" trailing
      """,
      to: configFileURL
    )

    XCTAssertThrowsError(try Config.validate(configPathOverride: configFileURL.path)) { error in
      guard let configError = error as? ConfigError else {
        return XCTFail("Expected ConfigError, got \(error)")
      }

      XCTAssertEqual(configError.problemItem, "[logging].level")
      XCTAssertEqual(configError.problemValue, #""debug" trailing"#)
    }
  }

  /// Verifies that parse-error value context preserves hashes inside strings.
  func testParseFailureContextPreservesQuotedHashInValue() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-value-context.toml")

    try writeConfig(
      """
      [logging]
      level = "de#bug" trailing # outer comment
      """,
      to: configFileURL
    )

    XCTAssertThrowsError(try Config.validate(configPathOverride: configFileURL.path)) { error in
      guard let configError = error as? ConfigError else {
        return XCTFail("Expected ConfigError, got \(error)")
      }

      XCTAssertEqual(configError.problemItem, "[logging].level")
      XCTAssertEqual(configError.problemValue, #""de#bug" trailing"#)
    }
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

}
