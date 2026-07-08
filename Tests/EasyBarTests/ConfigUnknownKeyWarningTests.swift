import EasyBarConfigSchema
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class ConfigUnknownKeyWarningTests: ConfigLoaderTestCase {
  /// Verifies that validate-config reports typoed keys without rejecting the config.
  func testValidateConfigWarnsAboutUnknownScalarKey() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("unknown-key.toml")

    try writeConfig(
      """
      [builtins.cpu.content]
      histroy_size = 10
      """,
      to: configFileURL
    )

    let result = try ConfigValidator.validate(configPathOverride: configFileURL.path)

    XCTAssertEqual(result.configPath, configFileURL.path)
    XCTAssertEqual(result.warnings, ["unknown config key builtins.cpu.content.histroy_size"])
  }

  /// Verifies that validate-config reports unknown sections once without noisy child warnings.
  func testValidateConfigWarnsAboutUnknownSection() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("unknown-section.toml")

    try writeConfig(
      """
      [builtins.cpu.contnet]
      history_size = 10
      """,
      to: configFileURL
    )

    let result = try ConfigValidator.validate(configPathOverride: configFileURL.path)

    XCTAssertEqual(result.warnings, ["unknown config section builtins.cpu.contnet"])
  }

  /// Verifies that removed legacy calendar aliases are reported as unknown keys.
  func testValidateConfigWarnsAboutLegacyMonthAnchorAliases() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("legacy-anchor-key.toml")

    try writeConfig(
      """
      [builtins.calendar.month.popup.anchor]
      anchor_date_format = "EEE d MMM"
      """,
      to: configFileURL
    )

    let result = try ConfigValidator.validate(configPathOverride: configFileURL.path)

    XCTAssertEqual(
      result.warnings,
      ["unknown config key builtins.calendar.month.popup.anchor.anchor_date_format"]
    )
  }

  /// Verifies that intentionally dynamic config tables do not produce unknown-key warnings.
  func testValidateConfigDoesNotWarnForDynamicTables() throws {
    let configFileURL = tempDirectoryURL.appendingPathComponent("dynamic-tables.toml")

    try writeConfig(
      """
      [app.env]
      CUSTOM_TOOL = "/usr/local/bin/tool"

      [builtins.groups.status]
      position = "right"
      order = 30

      [builtins.groups.status.style]
      background_color = "theme.surface"

      [builtins.calendar.composer.alert_labels]
      tomorrow_morning = "Tomorrow morning"
      """,
      to: configFileURL
    )

    let result = try ConfigValidator.validate(configPathOverride: configFileURL.path)

    XCTAssertEqual(result.warnings, [])
  }

  /// Verifies that the checked-in default config stays covered by the known-key schema.
  func testDefaultConfigContainsOnlyKnownKeys() throws {
    let defaultConfigURL = repoRootURL().appendingPathComponent("config.defaults.toml")

    let result = try ConfigValidator.validate(configPathOverride: defaultConfigURL.path)

    XCTAssertEqual(result.warnings, [])
  }

  /// Verifies that active and commented keys documented in config.defaults.toml stay covered.
  func testDocumentedDefaultConfigKeysAreCoveredByKnownKeySchema() throws {
    let defaultConfigURL = repoRootURL().appendingPathComponent("config.defaults.toml")
    let text = try String(contentsOf: defaultConfigURL, encoding: .utf8)
    let documentedKeys = documentedConfigKeys(from: text)

    XCTAssertFalse(documentedKeys.isEmpty)

    for documentedKey in documentedKeys {
      XCTAssertTrue(
        ConfigSchemaRegistry.isKnownSection(documentedKey.section),
        "Unknown documented config section \(documentedKey.section)"
      )

      guard !ConfigSchemaRegistry.isFreeFormSection(documentedKey.section) else {
        continue
      }

      XCTAssertTrue(
        ConfigSchemaRegistry.knownKeys(for: documentedKey.section).contains(documentedKey.key),
        "Unknown documented config key \(documentedKey.section).\(documentedKey.key)"
      )
    }
  }
}

private struct DocumentedConfigKey {
  let section: String
  let key: String
}

private func documentedConfigKeys(from text: String) -> [DocumentedConfigKey] {
  var section = ""
  var keys: [DocumentedConfigKey] = []

  for rawLine in text.components(separatedBy: .newlines) {
    guard let line = normalizedConfigLine(rawLine) else { continue }

    if line.hasPrefix("[") && line.hasSuffix("]") {
      section = String(line.dropFirst().dropLast())
        .trimmingCharacters(in: .whitespacesAndNewlines)
      continue
    }

    guard let equalsIndex = line.firstIndex(of: "=") else { continue }

    let key = line[..<equalsIndex]
      .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !key.isEmpty else { continue }
    keys.append(DocumentedConfigKey(section: section, key: key))
  }

  return keys
}

private func normalizedConfigLine(_ rawLine: String) -> String? {
  let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return nil }

  if trimmed.hasPrefix("#") {
    let uncommented = trimmed.dropFirst()
      .trimmingCharacters(in: .whitespacesAndNewlines)

    if uncommented.hasPrefix("[") {
      return uncommented
    }

    guard let equalsIndex = uncommented.firstIndex(of: "=") else {
      return nil
    }

    let key = uncommented[..<equalsIndex]
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard isBareConfigKey(key) else { return nil }

    return uncommented
  }

  return trimmed
}

private func isBareConfigKey(_ key: String) -> Bool {
  key.range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil
}
