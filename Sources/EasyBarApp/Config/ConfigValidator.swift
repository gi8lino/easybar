import EasyBarShared
import Foundation

/// Dry-run config validation entry point used by CLI tooling.
public enum ConfigValidator {
  /// Result of one validation run.
  public struct Result {
    /// Resolved path of the validated config file.
    public let configPath: String
    /// Non-fatal configuration warnings discovered during validation.
    public let warnings: [String]
  }

  /// Validates config without mutating the live app singleton state.
  public static func validate(configPathOverride: String? = nil) throws -> Result {
    let loadedState = try Config.validate(configPathOverride: configPathOverride)

    let resolvedPath =
      expandedPath(configPathOverride)
      ?? expandedPath(ProcessInfo.processInfo.environment[SharedEnvironmentKeys.configPath])
      ?? SharedPathDefaults.defaultConfigPath().path

    return Result(
      configPath: resolvedPath,
      warnings: loadedState.warnings + warnings(for: loadedState.snapshot)
    )
  }

  /// Returns warnings for valid but surprising configuration combinations.
  private static func warnings(for snapshot: ConfigSnapshot) -> [String] {
    var warnings: [String] = []

    if snapshot.builtins.calendar.enabled && !snapshot.calendarAgent.enabled {
      warnings.append(
        "builtins.calendar is enabled, but agents.calendar.enabled is false; the calendar widget will not receive calendar data."
      )
    }

    if snapshot.builtins.wifi.enabled && !snapshot.networkAgent.enabled {
      warnings.append(
        "builtins.wifi is enabled, but agents.network.enabled is false; the Wi-Fi widget will not receive network data."
      )
    }

    let wifi = snapshot.builtins.wifi
    if wifi.enabled && wifi.mode != .icon && !wifi.fields.hasEnabledField {
      warnings.append(
        "builtins.wifi.content.mode is \"\(wifi.mode.rawValue)\", but no builtins.wifi.fields entries are enabled."
      )
    }

    return warnings
  }
}
