import Foundation

/// Central registry of user-facing environment variable names used by EasyBar.
///
/// Normal runtime behavior should be configured in `config.toml`. The config
/// path is the public bootstrap override because it is needed before the config
/// file can be read. The log level is intentionally kept as a narrow diagnostic
/// override for local debugging and service troubleshooting.
public enum SharedEnvironmentKeys {
  public static let configPath = "EASYBAR_CONFIG_PATH"

  /// Optional diagnostic override for the configured logging level.
  public static let loggingLevel = "EASYBAR_LOG_LEVEL"
}
