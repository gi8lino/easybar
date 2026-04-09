import Foundation
import TOMLKit

/// Returns the resolved EasyBar config path, honoring EASYBAR_CONFIG_PATH.
func resolvedConfigPath() -> String {
  expandedEnvironmentPath(named: SharedEnvironmentKeys.configPath)
    ?? FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/easybar/config.toml")
    .path
}

/// Returns one parsed TOML table or an empty table when loading fails.
func parsedConfig(at path: String) -> TOMLTable {
  guard
    let text = try? String(contentsOfFile: path, encoding: .utf8),
    let table = try? TOMLTable(string: text)
  else {
    return TOMLTable()
  }

  return table
}
