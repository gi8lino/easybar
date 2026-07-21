import Foundation

/// Normalized CoreWLAN Wi-Fi state.
struct NetworkWiFiSnapshot: Equatable, Sendable {
  /// Empty fallback snapshot used before monitoring produces a sample.
  static let empty = NetworkWiFiSnapshot(
    ssid: nil,
    bssid: nil,
    interfaceName: nil,
    hardwareAddress: nil,
    power: nil,
    serviceActive: nil,
    rssi: nil,
    noise: nil,
    snr: nil,
    linkQuality: nil,
    txRate: nil,
    channel: nil,
    channelBand: nil,
    channelWidth: nil,
    security: nil,
    phyMode: nil,
    interfaceMode: nil,
    countryCode: nil,
    roaming: false,
    ssidChangedAt: nil,
    interfaceChangedAt: nil
  )

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
