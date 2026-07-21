import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp

final class ConfigEnvironmentValidationTests: ConfigLoaderTestCase {
  func testReloadRejectsEnvironmentKeyThatCannotBeEncodedInEnvp() throws {
    let config = Config.makeUnloadedConfig()
    let configFileURL = tempDirectoryURL.appendingPathComponent("invalid-environment.toml")
    try writeConfig(
      """
      [app.env]
      "BAD=KEY" = "value"
      """,
      to: configFileURL
    )
    setEnvironmentValue(configFileURL.path, for: SharedEnvironmentKeys.configPath)

    let error = try XCTUnwrap(config.reload())
    let configError = try XCTUnwrap(error as? ConfigError)

    XCTAssertEqual(configError.configPath, "app.env")
    XCTAssertTrue(configError.localizedDescription.contains("invalid process environment key"))
  }
}
