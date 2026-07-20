import CoreWLAN
import EasyBarShared
import Foundation

/// Watches CoreWLAN Wi-Fi state.
final class NetworkWiFiMonitor: NSObject, CWEventDelegate {
  private let smoothingFactor = 0.35
  private struct TrackingState {
    var smoothedRSSI: Double?
    var lastSSID: String?
    var lastBSSID: String?
    var lastInterface: String?
    var ssidChangedAt: Date?
    var interfaceChangedAt: Date?
    var roaming = false
  }

  private let trackingState = LockedState(TrackingState())
  private let componentName: String
  private let logger: ProcessLogger

  private var onChange: (() -> Void)?
  private var wifiClient: CWWiFiClient?

  /// Creates one Wi-Fi monitor that logs through the provided logger.
  init(componentName: String, logger: ProcessLogger) {
    self.componentName = componentName
    self.logger = logger
    super.init()
  }

  /// Starts listening for Wi-Fi changes.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    guard wifiClient == nil else {
      return
    }

    let client = CWWiFiClient.shared()
    client.delegate = self
    wifiClient = client

    do {
      try client.startMonitoringEvent(with: .ssidDidChange)
      try client.startMonitoringEvent(with: .bssidDidChange)
      try client.startMonitoringEvent(with: .countryCodeDidChange)
      try client.startMonitoringEvent(with: .linkDidChange)
      try client.startMonitoringEvent(with: .linkQualityDidChange)
      try client.startMonitoringEvent(with: .modeDidChange)
      try client.startMonitoringEvent(with: .powerDidChange)
      try client.startMonitoringEvent(with: .scanCacheUpdated)
      logger.info(
        "\(componentName) subscribed",
        .field("event", "wifi_change"),
      )
    } catch {
      let registrationError = error

      do {
        try client.stopMonitoringAllEvents()
        client.delegate = nil
        wifiClient = nil
      } catch {
        // Keep the client retained so a later stop can retry cleanup instead
        // of registering over a partially active callback set.
        logger.error(
          "failed to roll back partial \(componentName) Wi-Fi monitoring",
          .field("error", error),
        )
      }

      logger.warn(
        "failed to subscribe \(componentName) Wi-Fi events",
        .field("error", registrationError),
      )
    }
  }

  /// Stops Wi-Fi monitoring.
  func stop() {
    onChange = nil

    if let wifiClient {
      do {
        try wifiClient.stopMonitoringAllEvents()
        wifiClient.delegate = nil
        self.wifiClient = nil
      } catch {
        // Retain the client after a failed stop so a later stop or restart can
        // retry cleanup without creating duplicate event registrations.
        logger.warn(
          "failed to stop Wi-Fi monitoring",
          .field("error", error),
        )
      }
    }

    trackingState.withLock { state in
      state = TrackingState()
    }
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
    logger.info(
      "\(componentName) Wi-Fi SSID changed",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Handles one Wi-Fi BSSID change callback.
  func bssidDidChangeForWiFiInterface(withName interfaceName: String) {
    logger.info(
      "\(componentName) Wi-Fi BSSID changed",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Handles one Wi-Fi country code change callback.
  func countryCodeDidChangeForWiFiInterface(withName interfaceName: String) {
    logger.info(
      "\(componentName) Wi-Fi country code changed",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Handles one Wi-Fi link change callback.
  func linkDidChangeForWiFiInterface(withName interfaceName: String) {
    logger.info(
      "\(componentName) Wi-Fi link changed",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Handles one Wi-Fi link quality change callback.
  func linkQualityDidChangeForWiFiInterface(
    withName interfaceName: String, rssi: Int, transmitRate: Double
  ) {
    logger.info(
      "\(componentName) Wi-Fi link quality changed",
      .field("interface", interfaceName),
      .field("rssi", rssi),
      .field("tx_rate", transmitRate),
    )
    onChange?()
  }

  /// Handles one Wi-Fi mode change callback.
  func modeDidChangeForWiFiInterface(withName interfaceName: String) {
    logger.info(
      "\(componentName) Wi-Fi mode changed",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Handles one Wi-Fi power change callback.
  func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
    logger.info(
      "\(componentName) Wi-Fi power changed",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Handles one Wi-Fi scan cache update callback.
  func scanCacheUpdatedForWiFiInterface(withName interfaceName: String) {
    logger.debug(
      "\(componentName) Wi-Fi scan cache updated",
      .field("interface", interfaceName),
    )
    onChange?()
  }

  /// Smooths RSSI so the UI does not jump on every sample.
  private func smoothedRSSIValue(from rssi: Int?) -> Int? {
    trackingState.withLock { state in
      guard let rssi else {
        state.smoothedRSSI = nil
        logger.debug(
          "\(componentName) RSSI unavailable",
          .field("rssi", "<none>"),
        )
        return nil
      }

      guard let smoothedRSSI = state.smoothedRSSI else {
        state.smoothedRSSI = Double(rssi)
        return rssi
      }

      state.smoothedRSSI = (smoothedRSSI * (1 - smoothingFactor)) + (Double(rssi) * smoothingFactor)
      return Int((state.smoothedRSSI ?? Double(rssi)).rounded())
    }
  }

  /// Updates cached SSID and interface change tracking.
  private func updateChangeTracking(
    ssid: String?,
    bssid: String?,
    interface: String?,
    now: Date
  ) -> (roaming: Bool, ssidChangedAt: String?, interfaceChangedAt: String?) {
    trackingState.withLock { state in
      if state.lastSSID != ssid {
        state.ssidChangedAt = now
      }

      if state.lastInterface != interface {
        state.interfaceChangedAt = now
      }

      if state.lastSSID == ssid,
        ssid != nil,
        state.lastBSSID != nil,
        bssid != nil,
        state.lastBSSID != bssid
      {
        state.roaming = true
      } else {
        state.roaming = false
      }

      state.lastSSID = ssid
      state.lastBSSID = bssid
      state.lastInterface = interface

      return (
        roaming: state.roaming,
        ssidChangedAt: state.ssidChangedAt.map(
          NetworkWiFiSnapshot.fieldDateFormatter.string(from:)),
        interfaceChangedAt: state.interfaceChangedAt.map(
          NetworkWiFiSnapshot.fieldDateFormatter.string(from:))
      )
    }
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
