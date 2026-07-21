import Foundation

/// Protocol-owned normalization for CoreWLAN numeric values.
enum NetworkWiFiNormalization {
  /// Returns one stable channel-band label from a CoreWLAN raw value.
  static func channelBand(rawValue: Int) -> String {
    switch rawValue {
    case 1: return "2.4ghz"
    case 2: return "5ghz"
    case 3: return "6ghz"
    default: return "unknown"
    }
  }

  /// Returns one stable channel-width label from a CoreWLAN raw value.
  static func channelWidth(rawValue: Int) -> String {
    switch rawValue {
    case 1: return "20mhz"
    case 2: return "40mhz"
    case 3: return "80mhz"
    case 4: return "160mhz"
    default: return "unknown"
    }
  }

  /// Returns one stable Wi-Fi security label from a CoreWLAN raw value.
  static func security(rawValue: Int) -> String {
    switch rawValue {
    case 0: return "open"
    case 1: return "wep"
    case 2: return "wpa_personal"
    case 3: return "wpa_personal_mixed"
    case 4: return "wpa2_personal"
    case 5: return "personal"
    case 6: return "dynamic_wep"
    case 7: return "wpa_enterprise"
    case 8: return "wpa_enterprise_mixed"
    case 9: return "wpa2_enterprise"
    case 10: return "enterprise"
    case 11: return "wpa3_personal"
    case 12: return "wpa3_enterprise"
    case 13: return "wpa3_transition"
    case 14: return "enhanced_open"
    case 15: return "enhanced_open_transition"
    default: return "unknown"
    }
  }

  /// Returns one stable PHY label from a CoreWLAN raw value.
  static func phyMode(rawValue: Int) -> String {
    switch rawValue {
    case 0: return "none"
    case 1: return "802.11a"
    case 2: return "802.11b"
    case 3: return "802.11g"
    case 4: return "802.11n"
    case 5: return "802.11ac"
    case 6: return "802.11ax"
    case 7: return "802.11be"
    default: return "unknown"
    }
  }

  /// Returns one stable interface-mode label from a CoreWLAN raw value.
  static func interfaceMode(rawValue: Int) -> String {
    switch rawValue {
    case 0: return "none"
    case 1: return "station"
    case 2: return "ibss"
    case 3: return "hostap"
    default: return "unknown"
    }
  }

  /// Safely converts a reported Mbps value into the integer wire contract.
  static func transmitRate(_ value: Double) -> Int? {
    guard value.isFinite, value > 0 else { return nil }
    let rounded = value.rounded()
    return Int(exactly: rounded)
  }
}
