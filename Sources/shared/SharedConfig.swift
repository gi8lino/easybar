import Foundation

/// Returns the resolved EasyBar config path, honoring EASYBAR_CONFIG_PATH.
func sharedResolvedConfigPath() -> String {
  guard
    let override = ProcessInfo.processInfo.environment["EASYBAR_CONFIG_PATH"]?
      .trimmingCharacters(in: .whitespacesAndNewlines),
    !override.isEmpty
  else {
    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/config.toml")
      .path
  }

  return NSString(string: override).expandingTildeInPath
}

/// Returns the raw EasyBar config file text when available.
func sharedConfigFileText() -> String? {
  try? String(
    contentsOfFile: sharedResolvedConfigPath(),
    encoding: .utf8
  )
}

/// Parses one shared boolean value used across helper processes.
func sharedParseBool(_ value: String) -> Bool? {
  switch value.lowercased() {
  case "1", "true", "yes", "on":
    return true
  case "0", "false", "no", "off":
    return false
  default:
    return nil
  }
}
