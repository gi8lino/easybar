import Foundation

/// Shared filesystem and runtime defaults used across EasyBar targets.
public enum SharedPathDefaults {
  public static let defaultConfigRelativePath = ".config/easybar/config.toml"
  public static let defaultWidgetsRelativePath = ".config/easybar/widgets"
  public static let defaultLoggingDirectoryRelativePath = ".config/easybar/logs"
  public static let defaultLuaPath = "/opt/homebrew/bin/lua"

  public static let defaultLuaEnvironment: [String: String] = [
    "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  ]

  /// Returns an absolute path by resolving one home-relative path.
  public static func homeRelativePath(_ relativePath: String) -> String {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(relativePath)
      .path
  }

  /// Returns the default config path in the current user's home directory.
  public static func defaultConfigPath() -> String {
    homeRelativePath(defaultConfigRelativePath)
  }

  /// Returns the default widgets path in the current user's home directory.
  public static func defaultWidgetsPath() -> String {
    homeRelativePath(defaultWidgetsRelativePath)
  }

  /// Returns the default logging directory in the current user's home directory.
  public static func defaultLoggingDirectory() -> String {
    homeRelativePath(defaultLoggingDirectoryRelativePath)
  }
}
