import EasyBarShared
import Foundation

/// Render-ready Wi-Fi label and icon presentation.
struct WiFiPresentation {
  let labelText: String
  let iconText: String
  let iconColorHex: String

  init(snapshot: NetworkAgentSnapshot?, config: Config.WiFiBuiltinConfig) {
    labelText = Self.labelText(snapshot: snapshot, config: config)
    iconText = Self.iconText(snapshot: snapshot)
    iconColorHex = Self.iconColorHex(snapshot: snapshot, config: config)
  }

  /// Returns the Wi-Fi bar count from RSSI.
  private static func signalBars(snapshot: NetworkAgentSnapshot?) -> Int {
    guard
      let snapshot,
      snapshot.accessGranted,
      snapshot.ssid != nil,
      let rssi = snapshot.rssi
    else {
      return 0
    }

    switch rssi {
    case let value where value >= -58:
      return 4
    case let value where value >= -67:
      return 3
    case let value where value >= -75:
      return 2
    case let value where value >= -83:
      return 1
    default:
      return 0
    }
  }

  /// Resolves the Wi-Fi signal icon.
  private static func iconText(snapshot: NetworkAgentSnapshot?) -> String {
    switch signalBars(snapshot: snapshot) {
    case 4:
      return "󰤨 "
    case 3:
      return "󰤥 "
    case 2:
      return "󰤢 "
    case 1:
      return "󰤟 "
    default:
      return "󰤮 "
    }
  }

  /// Resolves the Wi-Fi signal color.
  private static func iconColorHex(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> String {
    guard let snapshot, snapshot.accessGranted, snapshot.ssid != nil else {
      return config.inactiveColorHex
    }

    return config.activeColorHex
  }

  /// Resolves the label text for the current Wi-Fi state.
  private static func labelText(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> String {
    guard let snapshot else { return config.disconnectedText }

    guard snapshot.accessGranted else {
      return config.deniedText
    }

    return snapshot.ssid ?? config.disconnectedText
  }
}
