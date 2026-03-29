import EasyBarShared
import Foundation

extension Config {

  /// Returns the config path override from the environment when present.
  func environmentConfigPathOverride() -> String? {
    expandedEnvironmentPath(named: "EASYBAR_CONFIG_PATH")
  }

  /// Returns the debug logging override from the environment when present.
  func environmentDebugOverride() -> Bool? {
    boolEnvironmentValue(named: "EASYBAR_DEBUG")
  }
}
