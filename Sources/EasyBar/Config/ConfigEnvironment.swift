import EasyBarShared
import Foundation

extension Config {

  /// Returns the config path override from the environment when present.
  func environmentConfigPathOverride() -> String? {
    expandedEnvironmentPath(named: "EASYBAR_CONFIG_PATH")
  }

  /// Returns the log-level override from the environment when present.
  func environmentLogLevelOverride() -> ProcessLogLevel? {
    ProcessLogLevel.normalized(stringEnvironmentValue(named: "EASYBAR_LOG_LEVEL"))
  }
}
