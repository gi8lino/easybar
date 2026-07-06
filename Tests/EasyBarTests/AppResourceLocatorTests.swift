import Foundation
import XCTest

@testable import EasyBarApp

final class AppResourceLocatorTests: XCTestCase {
  func testFindsLuaRuntimeFromSourceTree() throws {
    let url = try XCTUnwrap(
      AppResourceLocator.url(forResource: "runtime", withExtension: "lua")
    )

    XCTAssertTrue(url.path.hasSuffix("Sources/EasyBarApp/Lua/runtime.lua"))
  }

  func testEventCatalogCandidatesIncludePackagedAndSourceLayouts() {
    let paths = AppResourceLocator.resourceCandidates(
      forResource: "event_catalog",
      withExtension: "json",
      subdirectory: nil
    ).map(\.path)

    XCTAssertTrue(
      paths.contains { $0.hasSuffix("Resources/EasyBar/Events/event_catalog.json") },
      "Expected packaged event catalog candidate in \(paths)"
    )
    XCTAssertTrue(
      paths.contains { $0.hasSuffix("Sources/EasyBarApp/Events/event_catalog.json") },
      "Expected source event catalog candidate in \(paths)"
    )
  }

  func testThemeTokenCandidatesMapLogicalSubdirectoryPerLayout() {
    let paths = AppResourceLocator.resourceCandidates(
      forResource: "theme_tokens",
      withExtension: "json",
      subdirectory: "ThemeTokens"
    ).map(\.path)

    XCTAssertTrue(
      paths.contains { $0.hasSuffix("Resources/EasyBar/ThemeTokens/theme_tokens.json") },
      "Expected packaged theme-token candidate in \(paths)"
    )
    XCTAssertTrue(
      paths.contains { $0.hasSuffix("Sources/EasyBarApp/Theme/theme_tokens.json") },
      "Expected source theme-token candidate in \(paths)"
    )
  }

  func testLuaSubdirectoryCandidatesStayUnderLuaTree() {
    let paths = AppResourceLocator.resourceCandidates(
      forResource: "json",
      withExtension: "lua",
      subdirectory: "easybar"
    ).map(\.path)

    XCTAssertTrue(
      paths.contains { $0.hasSuffix("Resources/EasyBar/Lua/easybar/json.lua") },
      "Expected packaged Lua subdirectory candidate in \(paths)"
    )
    XCTAssertTrue(
      paths.contains { $0.hasSuffix("Sources/EasyBarApp/Lua/easybar/json.lua") },
      "Expected source Lua subdirectory candidate in \(paths)"
    )
  }
}
