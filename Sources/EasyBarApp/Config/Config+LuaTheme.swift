import Foundation

extension Config {
  /// Environment key used to pass the resolved active theme to the Lua runtime.
  static let luaThemeEnvironmentKey = "EASYBAR_INTERNAL_THEME_JSON"

  /// Returns environment values required by the Lua runtime.
  func luaThemeEnvironment() -> [String: String] {
    return snapshot().luaThemeEnvironment()
  }
}

extension ConfigSnapshot {
  /// Internal environment key used to expose the resolved logging directory to Lua widgets.
  static let luaLoggingDirectoryEnvironmentKey = "EASYBAR_INTERNAL_LOGGING_DIRECTORY"

  /// Returns environment values required by the Lua runtime.
  func luaThemeEnvironment() -> [String: String] {
    var environment = [
      Self.luaLoggingDirectoryEnvironmentKey: logging.directory
    ]

    guard let value = luaThemeJSONString() else {
      return environment
    }

    environment[Config.luaThemeEnvironmentKey] = value
    return environment
  }

  /// Encodes the resolved active theme for Lua widgets.
  private func luaThemeJSONString() -> String? {
    let payload: [String: Any] = [
      "name": theme.name,
      "colors": theme.colors.valuesByName,
    ]

    guard JSONSerialization.isValidJSONObject(payload) else {
      return nil
    }

    guard
      let data = try? JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys]
      )
    else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }
}
