import Foundation

/// Central registry of user-facing environment variable names used by EasyBar.
///
/// Normal runtime behavior should be configured in `config.toml`. The config
/// path is the only public bootstrap override because it is needed before the
/// config file can be read.
public enum SharedEnvironmentKeys {
  public static let configPath = "EASYBAR_CONFIG_PATH"
}
