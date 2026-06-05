import Foundation

/// Builds non-fatal warnings for valid but surprising configuration combinations.
enum ConfigWarningBuilder {
  /// Returns warnings for a fully parsed config snapshot.
  static func warnings(for snapshot: ConfigSnapshot) -> [String] {
    var warnings: [String] = []

    appendAgentWarnings(snapshot, to: &warnings)
    appendWiFiWarnings(snapshot, to: &warnings)

    return warnings
  }

  /// Adds warnings for built-ins whose required helper agent is disabled.
  private static func appendAgentWarnings(_ snapshot: ConfigSnapshot, to warnings: inout [String]) {
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
  }

  /// Adds warnings for Wi-Fi display modes that cannot show useful details.
  private static func appendWiFiWarnings(_ snapshot: ConfigSnapshot, to warnings: inout [String]) {
    let wifi = snapshot.builtins.wifi
    guard wifi.enabled else { return }

    if wifi.mode != .icon && !wifi.fields.hasEnabledField {
      warnings.append(
        "builtins.wifi.content.mode is \"\(wifi.mode.rawValue)\", but no builtins.wifi.fields entries are enabled."
      )
    }
  }
}
