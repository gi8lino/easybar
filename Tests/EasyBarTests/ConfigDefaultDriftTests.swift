import XCTest

@testable import EasyBarApp

final class ConfigDefaultDriftTests: ConfigLoaderTestCase {
  /// Verifies that the checked-in full defaults file matches the built-in Swift defaults.
  func testConfigDefaultsTomlMatchesBuiltInDefaults() throws {
    let missingConfigURL =
      tempDirectoryURL
      .appendingPathComponent("missing", isDirectory: true)
      .appendingPathComponent("config.toml")
    let defaultSnapshot = try Config.validate(configPathOverride: missingConfigURL.path).snapshot
    let defaultsFileURL = repoRootURL().appendingPathComponent("config.defaults.toml")
    let loadedState = try Config.validate(configPathOverride: defaultsFileURL.path)
    let loadedSnapshot = loadedState.snapshot

    XCTAssertEqual(loadedState.warnings, [])

    assertAppDefaults(loadedSnapshot.app, match: defaultSnapshot.app)
    XCTAssertEqual(loadedSnapshot.logging.level, defaultSnapshot.logging.level)
    XCTAssertEqual(loadedSnapshot.logging.enabled, defaultSnapshot.logging.enabled)
    XCTAssertEqual(loadedSnapshot.logging.directory, defaultSnapshot.logging.directory)
    XCTAssertEqual(loadedSnapshot.calendarAgent.socketPath, defaultSnapshot.calendarAgent.socketPath)
    XCTAssertEqual(loadedSnapshot.calendarAgent.enabled, defaultSnapshot.calendarAgent.enabled)
    XCTAssertEqual(loadedSnapshot.networkAgent.socketPath, defaultSnapshot.networkAgent.socketPath)
    XCTAssertEqual(loadedSnapshot.networkAgent.enabled, defaultSnapshot.networkAgent.enabled)
    XCTAssertEqual(
      loadedSnapshot.networkAgent.refreshIntervalSeconds,
      defaultSnapshot.networkAgent.refreshIntervalSeconds
    )
    XCTAssertEqual(
      loadedSnapshot.networkAgent.allowUnauthorizedNonSensitiveFields,
      defaultSnapshot.networkAgent.allowUnauthorizedNonSensitiveFields
    )
    XCTAssertEqual(loadedSnapshot.theme.name, defaultSnapshot.theme.name)
    XCTAssertEqual(loadedSnapshot.theme.colors, defaultSnapshot.theme.colors)
    assertDefaultValue(loadedSnapshot.bar, matches: defaultSnapshot.bar, theme: loadedSnapshot.theme.colors)
    assertBuiltinDefaults(
      loadedSnapshot.builtins,
      match: defaultSnapshot.builtins,
      theme: loadedSnapshot.theme.colors
    )
  }

  /// Verifies app defaults except for the config file path itself.
  private func assertAppDefaults(
    _ actual: ConfigSnapshot.App,
    match expected: ConfigSnapshot.App
  ) {
    XCTAssertEqual(actual.widgetsPath, expected.widgetsPath)
    XCTAssertEqual(actual.luaPath, expected.luaPath)
    XCTAssertEqual(actual.luaSocketPath, expected.luaSocketPath)
    XCTAssertEqual(actual.environment, expected.environment)
    XCTAssertEqual(actual.watchConfigFile, expected.watchConfigFile)
    XCTAssertEqual(actual.lockDirectory, expected.lockDirectory)
    XCTAssertEqual(actual.widgetEditorStubPath, expected.widgetEditorStubPath)
    XCTAssertEqual(actual.develop, expected.develop)
    XCTAssertEqual(actual.luaCommandLimits, expected.luaCommandLimits)
  }

  /// Verifies all built-in widget defaults using stable reflected value snapshots.
  private func assertBuiltinDefaults(
    _ actual: ConfigSnapshot.Builtins,
    match expected: ConfigSnapshot.Builtins,
    theme: Config.ThemeColors
  ) {
    assertDefaultValue(actual.cpu, matches: expected.cpu, theme: theme)
    assertDefaultValue(actual.battery, matches: expected.battery, theme: theme)
    assertDefaultValue(actual.groups, matches: expected.groups, theme: theme)
    assertDefaultValue(actual.spaces, matches: expected.spaces, theme: theme)
    assertDefaultValue(actual.frontApp, matches: expected.frontApp, theme: theme)
    assertDefaultValue(actual.aerospaceMode, matches: expected.aerospaceMode, theme: theme)
    assertDefaultValue(actual.volume, matches: expected.volume, theme: theme)
    assertDefaultValue(actual.wifi, matches: expected.wifi, theme: theme)
    assertDefaultValue(actual.calendar, matches: expected.calendar, theme: theme)
    assertDefaultValue(actual.time, matches: expected.time, theme: theme)
    assertDefaultValue(actual.date, matches: expected.date, theme: theme)
  }

  /// Compares reflected values after resolving user-facing theme references to concrete colors.
  private func assertDefaultValue(
    _ actual: Any,
    matches expected: Any,
    theme: Config.ThemeColors,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      normalizedDefaultDescription(String(reflecting: actual), theme: theme),
      normalizedDefaultDescription(String(reflecting: expected), theme: theme),
      file: file,
      line: line
    )
  }

  /// Normalizes semantically equivalent values used by the defaults reference file.
  private func normalizedDefaultDescription(
    _ value: String,
    theme: Config.ThemeColors
  ) -> String {
    var normalized = value

    for token in ThemeColorToken.allCases {
      normalized = normalized.replacingOccurrences(
        of: "\"\(token.reference)\"",
        with: "\"\(theme[token])\""
      )
    }

    return normalized
  }
}
