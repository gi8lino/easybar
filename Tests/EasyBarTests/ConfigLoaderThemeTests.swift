import Darwin
import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class ConfigLoaderThemeTests: ConfigLoaderTestCase {
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

}
