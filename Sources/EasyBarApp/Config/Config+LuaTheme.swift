import Foundation

extension Config {
  /// Environment key used to pass the resolved active theme to the Lua runtime.
  static let luaThemeEnvironmentKey = "EASYBAR_THEME_JSON"

  /// Returns environment values required by the Lua runtime.
  func luaThemeEnvironment() -> [String: String] {
    guard let value = luaThemeJSONString() else {
      return [:]
    }

    return [Self.luaThemeEnvironmentKey: value]
  }

  /// Encodes the resolved active theme for Lua widgets.
  private func luaThemeJSONString() -> String? {
    let payload: [String: Any] = [
      "name": themeName,
      "colors": themeColors.valuesByName,
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
