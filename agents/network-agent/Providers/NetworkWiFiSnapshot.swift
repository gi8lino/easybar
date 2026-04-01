import Foundation

struct NetworkWiFiSnapshot {
  static let fieldDateFormatter = ISO8601DateFormatter()

  let ssid: String?
  let bssid: String?
  let interfaceName: String?
  let hardwareAddress: String?
  let power: Bool?
  let serviceActive: Bool?
  let rssi: Int?
  let noise: Int?
  let snr: Int?
  let linkQuality: Int?
  let txRate: Int?
  let channel: Int?
  let channelBand: String?
  let channelWidth: String?
  let security: String?
  let phyMode: String?
  let interfaceMode: String?
  let countryCode: String?
  let roaming: Bool
  let ssidChangedAt: String?
  let interfaceChangedAt: String?
}
