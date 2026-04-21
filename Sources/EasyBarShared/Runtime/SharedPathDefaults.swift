import Foundation

/// Shared filesystem and runtime defaults used across EasyBar targets.
public enum SharedPathDefaults {
  static let defaultConfigRelativePath = ".config/easybar/config.toml"
  static let defaultWidgetsRelativePath = ".config/easybar/widgets"
  static let defaultLoggingDirectoryRelativePath = ".local/state/easybar"
  static let defaultWidgetEditorStubRelativePath = "/.local/share/easybar/"

  public static let defaultLuaPath = "/opt/homebrew/bin/lua"
  public static let defaultLuaEnvironment: [String: String] = [
    "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  ]

  /// Returns an absolute path by resolving one home-relative path.
  public static func homeRelativePath(_ relativePath: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(relativePath)
  }

  /// Returns the default config path in the current user's home directory.
  public static func defaultConfigPath() -> URL {
    homeRelativePath(defaultConfigRelativePath)
  }

  /// Returns the default widgets path in the current user's home directory.
  public static func defaultWidgetsPath() -> URL {
    homeRelativePath(defaultWidgetsRelativePath)
  }

  /// Returns the default logging directory in the current user's home directory.
  public static func defaultLoggingDirectory() -> URL {
    homeRelativePath(defaultLoggingDirectoryRelativePath)
  }

  /// Returns the default widget editor stub path in the current user's home directory.
  public static func defaultWidgetEditorStubPath() -> URL {
    homeRelativePath(defaultWidgetEditorStubRelativePath)
  }
}
