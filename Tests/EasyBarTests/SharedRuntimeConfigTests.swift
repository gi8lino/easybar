import Darwin
import EasyBarShared
import Foundation
import XCTest

final class SharedRuntimeConfigTests: XCTestCase {
  private let environmentKeys = [
    SharedEnvironmentKeys.configPath,
    SharedEnvironmentKeys.loggingLevel,
  ]

  private var originalEnvironment: [String: String?] = [:]
  private var tempDirectoryURL: URL!

  /// Prepares isolated state before each test.
  override func setUpWithError() throws {
    try super.setUpWithError()

    originalEnvironment = environmentKeys.reduce(into: [:]) { result, key in
      result[key] = ProcessInfo.processInfo.environment[key]
    }
    tempDirectoryURL = try makeTemporaryDirectory()
  }

  /// Restores state mutated by the test fixture.
  override func tearDownWithError() throws {
    restoreEnvironment()

    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  /// Verifies that load uses the config path environment override and TOML runtime values.
  func testLoadUsesConfigPathEnvironmentOverrideAndTomlValues() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-config.toml")
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
      [logging]
      level = "trace"
      directory = "\(loggingDirectory)"

      [app]
      lua_socket_path = "\(luaSocketPath)"

      [agents.calendar]
      socket_path = "\(calendarSocketPath)"

      [agents.network]
      socket_path = "\(networkSocketPath)"
      refresh_interval_seconds = 90
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let runtime = try SharedRuntimeConfig.load()

    XCTAssertEqual(runtime.configPath, configFileURL.path)
    XCTAssertEqual(runtime.logging.level, .trace)
    XCTAssertEqual(runtime.logging.directory, loggingDirectory)
    XCTAssertEqual(runtime.app.luaSocketPath, luaSocketPath)
    XCTAssertEqual(runtime.calendarAgent.socketPath, calendarSocketPath)
    XCTAssertEqual(runtime.networkAgent.socketPath, networkSocketPath)
    XCTAssertEqual(runtime.networkAgent.refreshIntervalSeconds, 90)
  }

  /// Verifies that load lets the diagnostic log-level environment override TOML.
  func testLoadPrefersEnvironmentLoggingLevelOverTomlValue() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-logging-env.toml")

    try writeConfig(
      """
      [logging]
      level = "info"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue("trace", for: SharedEnvironmentKeys.loggingLevel)

    let runtime = try SharedRuntimeConfig.load()

    XCTAssertEqual(runtime.configPath, configFileURL.path)
    XCTAssertEqual(runtime.logging.level, .trace)
  }

  /// Verifies that invalid shared TOML fails instead of silently falling back to defaults.
  func testLoadThrowsForInvalidToml() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-invalid.toml")

    try writeConfig(
      """
      [logging
      level = "info"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    XCTAssertThrowsError(try SharedRuntimeConfig.load()) { error in
      guard case SharedRuntimeConfigError.parseFailure(let path, _) = error else {
        return XCTFail("Expected parseFailure, got \(error)")
      }

      XCTAssertEqual(path, configFileURL.path)
    }
  }

  /// Verifies that shared helper config rejects invalid network intervals.
  func testLoadThrowsForNegativeNetworkAgentRefreshInterval() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-negative-network.toml")

    try writeConfig(
      """
      [agents.network]
      refresh_interval_seconds = -1
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    XCTAssertThrowsError(try SharedRuntimeConfig.load()) { error in
      guard case SharedRuntimeConfigError.invalidValue(let path, _) = error else {
        return XCTFail("Expected invalidValue, got \(error)")
      }

      XCTAssertEqual(path, "agents.network.refresh_interval_seconds")
    }
  }

  /// Verifies that shared runtime config rejects wrong TOML value types.
  func testLoadThrowsForInvalidSharedRuntimeValueType() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-invalid-type.toml")

    try writeConfig(
      """
      [logging]
      enabled = "yes"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    XCTAssertThrowsError(try SharedRuntimeConfig.load()) { error in
      guard case SharedRuntimeConfigError.invalidType(let path, let expected, _) = error else {
        return XCTFail("Expected invalidType, got \(error)")
      }

      XCTAssertEqual(path, "logging.enabled")
      XCTAssertEqual(expected, "bool")
    }
  }

  /// Verifies that invalid TOML logging levels are rejected instead of ignored.
  func testLoadThrowsForInvalidTomlLoggingLevel() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-invalid-log-level.toml")

    try writeConfig(
      """
      [logging]
      level = "verbose"
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    XCTAssertThrowsError(try SharedRuntimeConfig.load()) { error in
      guard case SharedRuntimeConfigError.invalidValue(let path, _) = error else {
        return XCTFail("Expected invalidValue, got \(error)")
      }

      XCTAssertEqual(path, "logging.level")
    }
  }

}

extension SharedRuntimeConfigTests {
  /// Creates an isolated temporary directory for file-system assertions.
  fileprivate func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-shared-runtime-tests-\(UUID().uuidString)",
        isDirectory: true
      )

    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )

    return directoryURL
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

  /// Restores environment variables captured before the test.
  fileprivate func restoreEnvironment() {
    for key in environmentKeys {
      setEnvironmentValue(originalEnvironment[key] ?? nil, for: key)
    }
  }
}
