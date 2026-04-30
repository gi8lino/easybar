import Darwin
import EasyBarShared
import Foundation
import XCTest

final class SharedRuntimeConfigTests: XCTestCase {
  private let environmentKeys = [
    SharedEnvironmentKeys.configPath,
    SharedEnvironmentKeys.loggingLevel,
    SharedEnvironmentKeys.loggingDirectory,
    SharedEnvironmentKeys.calendarAgentSocketPath,
    SharedEnvironmentKeys.networkAgentSocketPath,
    SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds,
  ]

  private var originalEnvironment: [String: String?] = [:]
  private var tempDirectoryURL: URL!

  override func setUpWithError() throws {
    try super.setUpWithError()

    originalEnvironment = environmentKeys.reduce(into: [:]) { result, key in
      result[key] = ProcessInfo.processInfo.environment[key]
    }
    tempDirectoryURL = try makeTemporaryDirectory()
  }

  override func tearDownWithError() throws {
    restoreEnvironment()

    if let tempDirectoryURL {
      try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    try super.tearDownWithError()
  }

  func testLoadPrefersEnvironmentOverridesOverTomlValues() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("runtime-config.toml")
    let envLoggingDirectory = tempDirectoryURL.appendingPathComponent("env-logs").path
    let envRuntimeDirectory = tempDirectoryURL.appendingPathComponent("env-runtime").path
    let envCalendarSocketPath = URL(fileURLWithPath: envRuntimeDirectory)
      .appendingPathComponent("calendar.sock")
      .path
    let envNetworkSocketPath = URL(fileURLWithPath: envRuntimeDirectory)
      .appendingPathComponent("network.sock")
      .path

    try writeConfig(
      """
      [logging]
      level = "info"
      directory = "\(tempDirectoryURL.appendingPathComponent("file-logs").path)"

      [agents.calendar]
      socket_path = "\(tempDirectoryURL.appendingPathComponent("file-runtime/calendar.sock").path)"

      [agents.network]
      socket_path = "\(tempDirectoryURL.appendingPathComponent("file-runtime/network.sock").path)"
      refresh_interval_seconds = 12
      """,
      to: configFileURL
    )

    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)
    setEnvironmentValue("trace", for: SharedEnvironmentKeys.loggingLevel)
    setEnvironmentValue(envLoggingDirectory, for: SharedEnvironmentKeys.loggingDirectory)
    setEnvironmentValue(envCalendarSocketPath, for: SharedEnvironmentKeys.calendarAgentSocketPath)
    setEnvironmentValue(envNetworkSocketPath, for: SharedEnvironmentKeys.networkAgentSocketPath)
    setEnvironmentValue("90", for: SharedEnvironmentKeys.networkAgentRefreshIntervalSeconds)

    let runtime = SharedRuntimeConfig.load()

    XCTAssertEqual(runtime.logging.level, .trace)
    XCTAssertEqual(runtime.logging.directory, envLoggingDirectory)
    XCTAssertEqual(runtime.calendarAgent.socketPath, envCalendarSocketPath)
    XCTAssertEqual(runtime.networkAgent.socketPath, envNetworkSocketPath)
    XCTAssertEqual(runtime.networkAgent.refreshIntervalSeconds, 90)
  }
}

extension SharedRuntimeConfigTests {
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
