import EasyBarConfigParsing
import EasyBarShared
import Foundation
import TOMLKit

extension Config {
  /// App-local TOML reader that raises `ConfigError` diagnostics.
  typealias ConfigReader = TOMLConfigReader<ConfigError>

  /// Creates a reader for one app config table.
  func configReader(
    table: TOMLTable,
    path: String
  ) -> ConfigReader {
    ConfigReader(
      table: table,
      path: path,
      makeInvalidTypeError: { path, expected, actual in
        ConfigError.invalidType(path: path, expected: expected, actual: actual)
      },
      makeInvalidValueError: { path, message in
        ConfigError.invalidValue(path: path, message: message)
      }
    )
  }
}

extension TOMLConfigReader where Failure == ConfigError {
  /// Returns an expanded path value or the fallback when absent.
  func expandedPath(_ key: String, fallback: String) throws -> String {
    EasyBarShared.expandedPath(try string(key, fallback: fallback)) ?? fallback
  }


  /// Returns an expanded optional path value or the fallback when absent.
  func optionalExpandedPath(_ key: String, fallback: String? = nil) throws -> String? {
    EasyBarShared.expandedPath(try optionalString(key, fallback: fallback))
  }
}


