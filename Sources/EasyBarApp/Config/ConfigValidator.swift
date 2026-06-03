import EasyBarShared
import Foundation

/// Dry-run config validation entry point used by CLI tooling.
public enum ConfigValidator {
  /// Result of one validation run.
  public struct Result {
    /// Resolved path of the validated config file.
    public let configPath: String
  }

  /// Validates config without mutating the live app singleton state.
  public static func validate(configPathOverride: String? = nil) throws -> Result {
    _ = try Config.validate(configPathOverride: configPathOverride)

    let resolvedPath =
      expandedPath(configPathOverride)
      ?? expandedPath(ProcessInfo.processInfo.environment[SharedEnvironmentKeys.configPath])
      ?? SharedPathDefaults.defaultConfigPath().path

    return Result(configPath: resolvedPath)
  }
}
