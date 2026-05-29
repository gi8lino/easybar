import EasyBarShared
import Foundation

/// Render-ready Wi-Fi label, details, and icon presentation.
struct WiFiPresentation {

  enum VisualState: String {
    case connected
    case disconnected
    case denied
  }

  struct DetailRow {
    let labelText: String
    let valueText: String
  }

  enum Content {
    case icon
    case field(String)
    case details([DetailRow])
  }

  let content: Content
  let signalLevel: Int
  let visualState: VisualState
  let activeColorHex: String
  let inactiveColorHex: String

  init(snapshot: NetworkAgentSnapshot?, config: Config.WiFiBuiltinConfig) {
    content = Self.content(snapshot: snapshot, config: config)
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

  /// Resolves the configured content block.
  private static func content(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> Content {
    switch config.mode {
    case .icon:
      return .icon
    case .field:
      let field = config.field ?? .ssid
      guard
        let text = fieldValue(for: field, snapshot: snapshot, config: config, inDetails: false)
      else {
        return .icon
      }
      return .field(text)
    case .details:
      let rows = detailRows(snapshot: snapshot, config: config)
      return rows.isEmpty ? .icon : .details(rows)
    }
  }

  /// Resolves one detail row list in a stable, user-facing order.
  private static func detailRows(
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig
  ) -> [DetailRow] {
    let fields: [(enabled: Bool, field: NetworkAgentField)] = [
      (config.fields.ssid, .ssid),
      (config.fields.ipv4Address, .ipv4Address),
      (config.fields.ipv6Address, .ipv6Address),
      (config.fields.rssi, .rssi),
      (config.fields.linkQuality, .linkQuality),
      (config.fields.txRate, .txRate),
      (config.fields.channel, .channel),
      (config.fields.channelBand, .channelBand),
      (config.fields.channelWidth, .channelWidth),
      (config.fields.security, .security),
      (config.fields.phyMode, .phyMode),
      (config.fields.interfaceName, .interfaceName),
      (config.fields.interfaceMode, .interfaceMode),
      (config.fields.bssid, .bssid),
      (config.fields.hardwareAddress, .hardwareAddress),
      (config.fields.power, .power),
      (config.fields.serviceActive, .serviceActive),
      (config.fields.noise, .noise),
      (config.fields.snr, .snr),
      (config.fields.countryCode, .countryCode),
      (config.fields.roaming, .roaming),
      (config.fields.ssidChangedAt, .ssidChangedAt),
      (config.fields.interfaceChangedAt, .interfaceChangedAt),
    ]

    return fields.compactMap { entry in
      guard entry.enabled else { return nil }
      guard let value = fieldValue(for: entry.field, snapshot: snapshot, config: config, inDetails: true)
      else {
        return nil
      }

      return DetailRow(
        labelText: fieldLabel(for: entry.field),
        valueText: value
      )
    }
  }

  /// Resolves one Wi-Fi field into displayable text.
  private static func fieldValue(
    for field: NetworkAgentField,
    snapshot: NetworkAgentSnapshot?,
    config: Config.WiFiBuiltinConfig,
    inDetails: Bool
  ) -> String? {
    guard let snapshot else {
      return disconnectedFallback(for: field, config: config, inDetails: inDetails)
    }

    guard snapshot.accessGranted else {
      return deniedFallback(for: field, config: config, inDetails: inDetails)
    }

    switch field {
    case .ssid:
      return snapshot.ssid ?? config.disconnectedText
    case .ipv4Address:
      return snapshot.ipv4Address
    case .ipv6Address:
      return snapshot.ipv6Address
    case .bssid:
      return snapshot.bssid
    case .interfaceName:
      return snapshot.interfaceName
    case .hardwareAddress:
      return snapshot.hardwareAddress
    case .power:
      return snapshot.power.map { $0 ? "on" : "off" }
    case .serviceActive:
      return snapshot.serviceActive.map { $0 ? "active" : "inactive" }
    case .rssi:
      return snapshot.rssi.map { "\($0) dBm" }
    case .noise:
      return snapshot.noise.map { "\($0) dBm" }
    case .snr:
      return snapshot.snr.map { "\($0) dB" }
    case .linkQuality:
      return snapshot.linkQuality.map { "\($0)%" }
    case .txRate:
      return snapshot.txRate.map { "\($0) Mbps" }
    case .channel:
      return snapshot.channel.map { "ch\($0)" }
    case .channelBand:
      return snapshot.channelBand.map(humanizedRadioValue)
    case .channelWidth:
      return snapshot.channelWidth.map(humanizedRadioValue)
    case .security:
      return snapshot.security.map(humanizedIdentifier)
    case .phyMode:
      return snapshot.phyMode
    case .interfaceMode:
      return snapshot.interfaceMode.map(humanizedIdentifier)
    case .countryCode:
      return snapshot.countryCode
    case .roaming:
      return snapshot.roaming.map { $0 ? "yes" : "no" }
    case .ssidChangedAt:
      return snapshot.ssidChangedAt
    case .interfaceChangedAt:
      return snapshot.interfaceChangedAt
    default:
      return nil
    }
  }

  /// Returns fallback text for disconnected Wi-Fi states.
  private static func disconnectedFallback(
    for field: NetworkAgentField,
    config: Config.WiFiBuiltinConfig,
    inDetails: Bool
  ) -> String? {
    guard field == .ssid else { return nil }
    return config.disconnectedText
  }

  /// Returns fallback text for denied Wi-Fi states.
  private static func deniedFallback(
    for field: NetworkAgentField,
    config: Config.WiFiBuiltinConfig,
    inDetails: Bool
  ) -> String? {
    guard field == .ssid else { return nil }
    return config.deniedText
  }

  /// Returns one stable, user-facing label for the provided field.
  private static func fieldLabel(for field: NetworkAgentField) -> String {
    switch field {
    case .ssid:
      return "SSID"
    case .ipv4Address:
      return "IPv4 Address"
    case .ipv6Address:
      return "IPv6 Address"
    case .bssid:
      return "BSSID"
    case .interfaceName:
      return "Interface"
    case .hardwareAddress:
      return "MAC"
    case .power:
      return "Power"
    case .serviceActive:
      return "Service"
    case .rssi:
      return "Signal"
    case .noise:
      return "Noise"
    case .snr:
      return "SNR"
    case .linkQuality:
      return "Link Quality"
    case .txRate:
      return "Rate"
    case .channel:
      return "Channel"
    case .channelBand:
      return "Band"
    case .channelWidth:
      return "Width"
    case .security:
      return "Security"
    case .phyMode:
      return "PHY"
    case .interfaceMode:
      return "Mode"
    case .countryCode:
      return "Country"
    case .roaming:
      return "Roaming"
    case .ssidChangedAt:
      return "SSID Changed"
    case .interfaceChangedAt:
      return "Interface Changed"
    default:
      return field.rawValue
    }
  }

  /// Humanizes Wi-Fi enum-like identifiers for display.
  private static func humanizedIdentifier(_ value: String) -> String {
    let parts =
      value
      .replacingOccurrences(of: "_", with: " ")
      .split(separator: " ")

    return parts.map { part in
      let raw = String(part)
      if raw.hasPrefix("wpa") || raw.hasPrefix("wep") {
        return raw.uppercased()
      }
      return raw.capitalized
    }.joined(separator: " ")
  }

  /// Humanizes radio values like `5ghz` and `80mhz`.
  private static func humanizedRadioValue(_ value: String) -> String {
    value
      .replacingOccurrences(of: "ghz", with: " GHz")
      .replacingOccurrences(of: "mhz", with: " MHz")
      .replacingOccurrences(of: "  ", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
