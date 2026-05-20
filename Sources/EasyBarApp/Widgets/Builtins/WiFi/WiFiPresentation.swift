import EasyBarShared
import Foundation

/// Render-ready Wi-Fi label and icon presentation.
struct WiFiPresentation {

  enum VisualState: String {
    case connected
    case disconnected
    case denied
  }

  let labelText: String
  let signalLevel: Int
  let visualState: VisualState
  let activeColorHex: String
  let inactiveColorHex: String

  init(snapshot: NetworkAgentSnapshot?, config: Config.WiFiBuiltinConfig) {
    labelText = Self.labelText(snapshot: snapshot, config: config)
    signalLevel = Self.signalLevel(snapshot: snapshot)
    visualState = Self.visualState(snapshot: snapshot)
    activeColorHex = config.activeColorHex
    inactiveColorHex = config.inactiveColorHex
  }

  /// Returns the visual signal level from RSSI in the 0...3 range.
  private static func signalLevel(snapshot: NetworkAgentSnapshot?) -> Int {
    guard
      let snapshot,
      snapshot.accessGranted,
      snapshot.ssid != nil,
      let rssi = snapshot.rssi
    else {
      return 0
    }

    switch rssi {
    case ..<(-78):
      return 1
    case ..<(-64):
      return 2
    default:
      return 3
    }
  }

  /// Resolves the Wi-Fi visual state.
  private static func visualState(snapshot: NetworkAgentSnapshot?) -> VisualState {
    guard let snapshot else { return .disconnected }
    guard snapshot.accessGranted else { return .denied }
    guard snapshot.ssid != nil else { return .disconnected }
    return .connected
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
