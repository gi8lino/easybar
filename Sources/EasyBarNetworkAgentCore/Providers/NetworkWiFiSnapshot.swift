import Foundation

/// Normalized CoreWLAN Wi-Fi state.
struct NetworkWiFiSnapshot {
  /// Formats field timestamps for wire values.
  nonisolated(unsafe) static let fieldDateFormatter = ISO8601DateFormatter()

  /// Current Wi-Fi network name.
  let ssid: String?
  /// Current access point BSSID.
  let bssid: String?
  /// Wi-Fi interface name.
  let interfaceName: String?
  /// Wi-Fi hardware address.
  let hardwareAddress: String?
  /// Wi-Fi power state.
  let power: Bool?
  /// CoreWLAN service state.
  let serviceActive: Bool?
  /// Smoothed RSSI value.
  let rssi: Int?
  /// Noise floor value.
  let noise: Int?
  /// Signal-to-noise ratio.
  let snr: Int?
  /// Derived link quality score.
  let linkQuality: Int?
  /// Transmit rate in Mbps.
  let txRate: Int?
  /// Current Wi-Fi channel.
  let channel: Int?
  /// Current Wi-Fi band.
  let channelBand: String?
  /// Current channel width.
  let channelWidth: String?
  /// Current security mode.
  let security: String?
  /// Current PHY mode.
  let phyMode: String?
  /// Current interface mode.
  let interfaceMode: String?
  /// Current Wi-Fi country code.
  let countryCode: String?
  /// Whether BSSID roaming was detected.
  let roaming: Bool
  /// Last SSID change timestamp.
  let ssidChangedAt: String?
  /// Last interface change timestamp.
  let interfaceChangedAt: String?
}
