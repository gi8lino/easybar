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

  /// Handles set up with error.
  override func setUpWithError() throws {
    try super.setUpWithError()

    originalEnvironment = environmentKeys.reduce(into: [:]) { result, key in
      result[key] = ProcessInfo.processInfo.environment[key]
    }
    tempDirectoryURL = try makeTemporaryDirectory()
  }

  /// Handles tear down with error.
  override func tearDownWithError() throws {
    restoreEnvironment()

    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  /// Handles test load uses the config path environment override and TOML runtime values.
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

    let runtime = SharedRuntimeConfig.load()

    XCTAssertEqual(runtime.configPath, configFileURL.path)
    XCTAssertEqual(runtime.logging.level, .trace)
    XCTAssertEqual(runtime.logging.directory, loggingDirectory)
    XCTAssertEqual(runtime.app.luaSocketPath, luaSocketPath)
    XCTAssertEqual(runtime.calendarAgent.socketPath, calendarSocketPath)
    XCTAssertEqual(runtime.networkAgent.socketPath, networkSocketPath)
    XCTAssertEqual(runtime.networkAgent.refreshIntervalSeconds, 90)
  }

  /// Handles test load lets the diagnostic log-level environment override TOML.
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

    let runtime = SharedRuntimeConfig.load()

    XCTAssertEqual(runtime.configPath, configFileURL.path)
    XCTAssertEqual(runtime.logging.level, .trace)
  }
}

extension SharedRuntimeConfigTests {
  /// Creates temporary directory.
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
