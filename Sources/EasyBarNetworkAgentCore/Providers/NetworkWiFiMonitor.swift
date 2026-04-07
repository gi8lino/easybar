import CoreWLAN
import EasyBarShared
import Foundation

final class NetworkWiFiMonitor: NSObject, CWEventDelegate {
  private let smoothingFactor = 0.35
  private let stateLock = NSLock()
  private let componentName: String
  private let logger: ProcessLogger

  private var onChange: (() -> Void)?
  private var wifiClient: CWWiFiClient?
  private var smoothedRSSI: Double?
  private var lastSSID: String?
  private var lastBSSID: String?
  private var lastInterface: String?
  private var ssidChangedAt: Date?
  private var interfaceChangedAt: Date?
  private var roaming = false

  /// Creates one Wi-Fi monitor that logs through the provided logger.
  init(componentName: String, logger: ProcessLogger) {
    self.componentName = componentName
    self.logger = logger
    super.init()
  }

  /// Starts listening for Wi-Fi changes.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    let client = CWWiFiClient.shared()
    client.delegate = self

    do {
      try client.startMonitoringEvent(with: .ssidDidChange)
      wifiClient = client
      logger.info("\(componentName) subscribed wifi_change")
    } catch {
      logger.warn("failed to subscribe \(componentName) Wi-Fi events: \(error)")
    }
  }

  /// Stops Wi-Fi monitoring.
  func stop() {
    if let wifiClient {
      do {
        try wifiClient.stopMonitoringAllEvents()
      } catch {
        logger.warn("failed to stop Wi-Fi monitoring: \(error)")
      }
    }

    wifiClient = nil
    onChange = nil
  }

  /// Returns the current normalized Wi-Fi state.
  func currentState(now: Date) -> NetworkWiFiSnapshot {
    let interface = CWWiFiClient.shared().interface()
    let ssid = normalized(interface?.ssid())
    let bssid = normalized(interface?.bssid())
    let interfaceName = normalized(interface?.interfaceName)
    let hardwareAddress = normalized(interface?.hardwareAddress())
    let power = interface?.powerOn()
    let serviceActive = interface?.serviceActive()
    let rssi = smoothedRSSIValue(from: validMeasurement(interface?.rssiValue()))
    let noise = validMeasurement(interface?.noiseMeasurement())
    let snr = makeSNR(rssi: rssi, noise: noise)
    let linkQuality = makeLinkQuality(snr: snr)
    let txRate = interface.map { Int($0.transmitRate()) }
    let channelInfo = interface?.wlanChannel()
    let phyMode = interface.map { phyModeString($0.activePHYMode()) }

    let changeTracking = updateChangeTracking(
      ssid: ssid,
      bssid: bssid,
      interface: interfaceName,
      now: now
    )

    return NetworkWiFiSnapshot(
      ssid: ssid,
      bssid: bssid,
      interfaceName: interfaceName,
      hardwareAddress: hardwareAddress,
      power: power,
      serviceActive: serviceActive,
      rssi: rssi,
      noise: noise,
      snr: snr,
      linkQuality: linkQuality,
      txRate: txRate,
      channel: channelInfo.map { Int($0.channelNumber) },
      channelBand: channelInfo.map { channelBandString($0.channelBand) },
      channelWidth: channelInfo.map { channelWidthString($0.channelWidth) },
      security: interface.map(securityString),
      phyMode: phyMode,
      interfaceMode: interface.map { interfaceModeString($0.interfaceMode()) },
      countryCode: normalized(interface?.countryCode()),
      roaming: changeTracking.roaming,
      ssidChangedAt: changeTracking.ssidChangedAt,
      interfaceChangedAt: changeTracking.interfaceChangedAt
    )
  }

  /// Handles one Wi-Fi SSID change callback.
  func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
    logger.info("\(componentName) Wi-Fi changed interface=\(interfaceName)")
    onChange?()
  }

  /// Smooths RSSI so the UI does not jump on every sample.
  private func smoothedRSSIValue(from rssi: Int?) -> Int? {
    stateLock.lock()
    defer { stateLock.unlock() }

    guard let rssi else {
      smoothedRSSI = nil
      logger.debug("\(componentName) RSSI unavailable")
      return nil
    }

    guard let smoothedRSSI else {
      self.smoothedRSSI = Double(rssi)
      return rssi
    }

    self.smoothedRSSI = (smoothedRSSI * (1 - smoothingFactor)) + (Double(rssi) * smoothingFactor)
    return Int((self.smoothedRSSI ?? Double(rssi)).rounded())
  }

  /// Updates cached SSID and interface change tracking.
  private func updateChangeTracking(
    ssid: String?,
    bssid: String?,
    interface: String?,
    now: Date
  ) -> (roaming: Bool, ssidChangedAt: String?, interfaceChangedAt: String?) {
    stateLock.lock()
    defer { stateLock.unlock() }

    if lastSSID != ssid {
      ssidChangedAt = now
    }

    if lastInterface != interface {
      interfaceChangedAt = now
    }

    if lastSSID == ssid, ssid != nil, lastBSSID != nil, bssid != nil, lastBSSID != bssid {
      roaming = true
    } else {
      roaming = false
    }

    lastSSID = ssid
    lastBSSID = bssid
    lastInterface = interface

    return (
      roaming: roaming,
      ssidChangedAt: ssidChangedAt.map(NetworkWiFiSnapshot.fieldDateFormatter.string(from:)),
      interfaceChangedAt: interfaceChangedAt.map(
        NetworkWiFiSnapshot.fieldDateFormatter.string(from:))
    )
  }

  /// Filters out unusable measurements from system APIs.
  private func validMeasurement(_ value: Int?) -> Int? {
    guard let value, value != 0 else { return nil }
    return value
  }

  /// Returns signal-to-noise ratio.
  private func makeSNR(rssi: Int?, noise: Int?) -> Int? {
    guard let rssi, let noise else { return nil }
    return rssi - noise
  }

  /// Returns a rough 0...100 link quality score.
  private func makeLinkQuality(snr: Int?) -> Int? {
    guard let snr else { return nil }
    return min(max((snr - 10) * 4, 0), 100)
  }

  /// Returns a normalized Wi-Fi band string.
  private func channelBandString(_ band: CWChannelBand) -> String {
    let raw = String(describing: band).lowercased()

    switch raw {
    case "band2ghz":
      return "2.4ghz"
    case "band5ghz":
      return "5ghz"
    case "band6ghz":
      return "6ghz"
    case "bandunknown":
      return "unknown"
    default:
      return "unknown"
    }
  }

  /// Returns a normalized Wi-Fi channel width string.
  private func channelWidthString(_ width: CWChannelWidth) -> String {
    let raw = String(describing: width).lowercased()

    switch raw {
    case "widthunknown":
      return "unknown"
    case "width20mhz":
      return "20mhz"
    case "width40mhz":
      return "40mhz"
    case "width80mhz":
      return "80mhz"
    case "width160mhz":
      return "160mhz"
    default:
      return raw.isEmpty ? "unknown" : raw
    }
  }

  /// Returns a normalized security string from the interface.
  private func securityString(_ interface: CWInterface) -> String {
    let raw = String(describing: interface.security())
      .replacingOccurrences(of: "CWSecurity", with: "")
      .replacingOccurrences(of: ".", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    switch raw {
    case "none":
      return "open"
    case "wep":
      return "wep"
    case "dynamicwep":
      return "dynamic_wep"
    case "wpapersonal":
      return "wpa_personal"
    case "wpapersonalmixed":
      return "wpa_personal_mixed"
    case "wpa2personal":
      return "wpa2_personal"
    case "personal":
      return "personal"
    case "wpaenterprise":
      return "wpa_enterprise"
    case "wpaenterprisemixed":
      return "wpa_enterprise_mixed"
    case "wpa2enterprise":
      return "wpa2_enterprise"
    case "enterprise":
      return "enterprise"
    case "wpa3personal":
      return "wpa3_personal"
    case "wpa3transition":
      return "wpa3_transition"
    case "wpa3enterprise":
      return "wpa3_enterprise"
    case "owe":
      return "enhanced_open"
    case "owetransition":
      return "enhanced_open_transition"
    case "unknown":
      return "unknown"
    default:
      return raw.isEmpty ? "unknown" : raw
    }
  }

  /// Returns a normalized PHY mode string.
  private func phyModeString(_ mode: CWPHYMode) -> String {
    let raw = String(describing: mode)
      .replacingOccurrences(of: "CWPHYMode", with: "")
      .replacingOccurrences(of: ".", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    switch raw.lowercased() {
    case "modenone", "none":
      return "none"
    case "mode11a", "11a":
      return "802.11a"
    case "mode11b", "11b":
      return "802.11b"
    case "mode11g", "11g":
      return "802.11g"
    case "mode11n", "11n":
      return "802.11n"
    case "mode11ac", "11ac":
      return "802.11ac"
    case "mode11ax", "11ax":
      return "802.11ax"
    default:
      return raw.isEmpty ? "unknown" : raw.lowercased()
    }
  }

  /// Returns a normalized interface mode string.
  private func interfaceModeString(_ mode: CWInterfaceMode) -> String {
    let raw = String(describing: mode)
      .replacingOccurrences(of: "CWInterfaceMode", with: "")
      .replacingOccurrences(of: ".", with: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    switch raw.lowercased() {
    case "modenone", "none":
      return "none"
    case "modestation", "station":
      return "station"
    case "modeibss", "ibss":
      return "ibss"
    case "modehostap", "hostap":
      return "hostap"
    default:
      return raw.isEmpty ? "unknown" : raw.lowercased()
    }
  }

  /// Trims one optional string and drops empty values.
  private func normalized(_ value: String?) -> String? {
    guard let value else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
