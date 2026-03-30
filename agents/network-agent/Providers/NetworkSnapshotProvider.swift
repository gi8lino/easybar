import CoreLocation
import CoreWLAN
import EasyBarShared
import Foundation
import SystemConfiguration

final class NetworkSnapshotProvider: NSObject, CLLocationManagerDelegate, CWEventDelegate {
  private static let fieldDateFormatter = ISO8601DateFormatter()
  private static let watchedNetworkPatterns: [CFString] = [
    "State:/Network/Global/IPv4" as CFString,
    "State:/Network/Global/IPv6" as CFString,
    "State:/Network/Global/DNS" as CFString,
    "State:/Network/Service/.*/IPv4" as CFString,
    "State:/Network/Service/.*/IPv6" as CFString,
  ]

  private let locationManager = CLLocationManager()
  private let authState = NetworkAgentAuthorizationState()
  private let smoothingFactor = 0.35
  private let refreshIntervalSeconds: TimeInterval
  private let stateLock = NSLock()

  private var onChange: (() -> Void)?
  private var wifiClient: CWWiFiClient?
  private var refreshTimer: Timer?
  private var smoothedRSSI: Double?
  private var lastSSID: String?
  private var lastBSSID: String?
  private var lastInterface: String?
  private var ssidChangedAt: Date?
  private var interfaceChangedAt: Date?
  private var roaming = false

  private var store: SCDynamicStore?
  private var storeSource: CFRunLoopSource?

  private struct WiFiState {
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

  private struct NetworkState {
    let primaryInterface: String?
    let activeTunnelInterface: String?
    let activeTunnelInterfaces: [String]
    let primaryInterfaceIsTunnel: Bool
    let ipv4Address: String?
    let ipv6Address: String?
    let defaultGateway: String?
    let dnsServers: [String]
    let internetReachable: Bool
    let captivePortal: Bool
  }

  /// Builds the network snapshot provider with one refresh interval.
  init(refreshIntervalSeconds: TimeInterval) {
    self.refreshIntervalSeconds = refreshIntervalSeconds
  }

  /// Starts permission, Wi-Fi, and network monitoring.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    locationManager.delegate = self
    authState.setStatus(locationManager.authorizationStatus)
    AgentLogger.info(
      "network agent authorization status before start=\(authState.permissionState())")
    locationManager.requestWhenInUseAuthorization()

    startWiFiMonitoring()
    startNetworkMonitoring()

    AgentLogger.info("network agent refresh_interval_seconds=\(refreshIntervalSeconds)")

    if refreshIntervalSeconds > 0 {
      refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) {
        [weak self] _ in
        self?.onChange?()
      }
    }

    onChange()
  }

  /// Stops timers and all active monitoring.
  func stop() {
    refreshTimer?.invalidate()
    refreshTimer = nil

    if let wifiClient {
      do {
        try wifiClient.stopMonitoringAllEvents()
      } catch {
        AgentLogger.warn("failed to stop Wi-Fi monitoring: \(error)")
      }
    }

    if let storeSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), storeSource, .commonModes)
    }

    storeSource = nil
    store = nil
    wifiClient = nil
    onChange = nil
  }

  /// Builds one network snapshot from current system state.
  func snapshot() -> NetworkAgentSnapshot {
    let now = Date()
    let permissionState = authState.permissionState()
    let wifi = currentWiFiState(now: now)
    let network = currentNetworkState()

    AgentLogger.debug(
      "network snapshot access_granted=\(authState.isAuthorized()) permission_state=\(permissionState) ssid=\(wifi.ssid ?? "<none>") interface=\(wifi.interfaceName ?? "<none>") rssi=\(wifi.rssi.map(String.init) ?? "<none>") primary_is_tunnel=\(network.primaryInterfaceIsTunnel)"
    )

    return NetworkAgentSnapshot(
      accessGranted: authState.isAuthorized(),
      permissionState: permissionState,
      generatedAt: now,
      ssid: wifi.ssid,
      interfaceName: wifi.interfaceName,
      primaryInterfaceIsTunnel: network.primaryInterfaceIsTunnel,
      rssi: wifi.rssi
    )
  }

  /// Returns the requested field values for the current network state.
  func fieldValues(for fields: [NetworkAgentField]) -> [String: String] {
    let now = Date()
    let permissionState = authState.permissionState()
    let locationAuthorized = authState.isAuthorized()
    let wifi = currentWiFiState(now: now)
    let network = currentNetworkState()
    var values: [String: String] = [:]

    for field in fields {
      switch field {
      case .generatedAt:
        values[field.rawValue] = Self.fieldDateFormatter.string(from: now)
      case .ssid:
        if let ssid = wifi.ssid {
          values[field.rawValue] = ssid
        }
      case .bssid:
        if let bssid = wifi.bssid {
          values[field.rawValue] = bssid
        }
      case .interfaceName:
        if let interfaceName = wifi.interfaceName {
          values[field.rawValue] = interfaceName
        }
      case .hardwareAddress:
        if let hardwareAddress = wifi.hardwareAddress {
          values[field.rawValue] = hardwareAddress
        }
      case .power:
        if let power = wifi.power {
          values[field.rawValue] = String(power)
        }
      case .serviceActive:
        if let serviceActive = wifi.serviceActive {
          values[field.rawValue] = String(serviceActive)
        }
      case .primaryInterfaceIsTunnel:
        values[field.rawValue] = String(network.primaryInterfaceIsTunnel)
      case .rssi:
        if let rssi = wifi.rssi {
          values[field.rawValue] = String(rssi)
        }
      case .noise:
        if let noise = wifi.noise {
          values[field.rawValue] = String(noise)
        }
      case .snr:
        if let snr = wifi.snr {
          values[field.rawValue] = String(snr)
        }
      case .linkQuality:
        if let linkQuality = wifi.linkQuality {
          values[field.rawValue] = String(linkQuality)
        }
      case .txRate:
        if let txRate = wifi.txRate {
          values[field.rawValue] = String(txRate)
        }
      case .channel:
        if let channel = wifi.channel {
          values[field.rawValue] = String(channel)
        }
      case .channelBand:
        if let channelBand = wifi.channelBand {
          values[field.rawValue] = channelBand
        }
      case .channelWidth:
        if let channelWidth = wifi.channelWidth {
          values[field.rawValue] = channelWidth
        }
      case .security:
        if let security = wifi.security {
          values[field.rawValue] = security
        }
      case .phyMode:
        if let phyMode = wifi.phyMode {
          values[field.rawValue] = phyMode
        }
      case .interfaceMode:
        if let interfaceMode = wifi.interfaceMode {
          values[field.rawValue] = interfaceMode
        }
      case .countryCode:
        if let countryCode = wifi.countryCode {
          values[field.rawValue] = countryCode
        }
      case .roaming:
        values[field.rawValue] = String(wifi.roaming)
      case .ssidChangedAt:
        if let ssidChangedAt = wifi.ssidChangedAt {
          values[field.rawValue] = ssidChangedAt
        }
      case .interfaceChangedAt:
        if let interfaceChangedAt = wifi.interfaceChangedAt {
          values[field.rawValue] = interfaceChangedAt
        }
      case .primaryInterface:
        if let primaryInterface = network.primaryInterface {
          values[field.rawValue] = primaryInterface
        }
      case .activeTunnelInterface:
        if let activeTunnelInterface = network.activeTunnelInterface {
          values[field.rawValue] = activeTunnelInterface
        }
      case .activeTunnelInterfaces:
        values[field.rawValue] = network.activeTunnelInterfaces.joined(separator: ",")
      case .ipv4Address:
        if let ipv4Address = network.ipv4Address {
          values[field.rawValue] = ipv4Address
        }
      case .ipv6Address:
        if let ipv6Address = network.ipv6Address {
          values[field.rawValue] = ipv6Address
        }
      case .defaultGateway:
        if let defaultGateway = network.defaultGateway {
          values[field.rawValue] = defaultGateway
        }
      case .dnsServers:
        values[field.rawValue] = network.dnsServers.joined(separator: ",")
      case .internetReachable:
        values[field.rawValue] = String(network.internetReachable)
      case .captivePortal:
        values[field.rawValue] = String(network.captivePortal)
      case .locationAuthorized:
        values[field.rawValue] = String(locationAuthorized)
      case .locationPermissionState:
        values[field.rawValue] = permissionState
      }
    }

    return values
  }

  /// Returns whether location access is currently authorized.
  func isLocationAuthorized() -> Bool {
    authState.isAuthorized()
  }

  /// Returns the current location permission label.
  func locationPermissionState() -> String {
    authState.permissionState()
  }

  /// Handles one location authorization change.
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.authState.setStatus(status)
      AgentLogger.info(
        "network agent authorization changed status=\(self.authState.permissionState())")
      self.onChange?()
    }
  }

  /// Handles one Wi-Fi SSID change callback.
  func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
    AgentLogger.info("network agent Wi-Fi changed interface=\(interfaceName)")
    onChange?()
  }

  /// Starts listening for Wi-Fi SSID changes.
  private func startWiFiMonitoring() {
    let client = CWWiFiClient.shared()
    client.delegate = self

    do {
      try client.startMonitoringEvent(with: .ssidDidChange)
      wifiClient = client
      AgentLogger.info("network agent subscribed wifi_change")
    } catch {
      AgentLogger.warn("failed to subscribe network agent Wi-Fi events: \(error)")
    }
  }

  /// Starts listening for primary network interface changes.
  private func startNetworkMonitoring() {
    var context = SCDynamicStoreContext(
      version: 0,
      info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      retain: nil,
      release: nil,
      copyDescription: nil
    )

    guard
      let store = SCDynamicStoreCreate(
        nil,
        "easybar-network-agent" as CFString,
        { _, _, info in
          guard let info else { return }
          let provider = Unmanaged<NetworkSnapshotProvider>.fromOpaque(info).takeUnretainedValue()
          DispatchQueue.main.async {
            provider.handleNetworkStoreChange()
          }
        },
        &context
      )
    else {
      AgentLogger.warn("failed to create network dynamic store")
      return
    }

    SCDynamicStoreSetNotificationKeys(store, nil, Self.watchedNetworkPatterns as CFArray)

    guard let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else {
      AgentLogger.warn("failed to create network dynamic store source")
      return
    }

    self.store = store
    storeSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    AgentLogger.info("network agent subscribed network_change")
  }

  /// Handles one dynamic store change callback.
  private func handleNetworkStoreChange() {
    AgentLogger.info("network agent dynamic store changed")
    onChange?()
  }

  /// Returns the current normalized Wi-Fi state.
  private func currentWiFiState(now: Date) -> WiFiState {
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

    return WiFiState(
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

  /// Returns the current normalized network state.
  private func currentNetworkState() -> NetworkState {
    guard let store else {
      return NetworkState(
        primaryInterface: nil,
        activeTunnelInterface: nil,
        activeTunnelInterfaces: [],
        primaryInterfaceIsTunnel: false,
        ipv4Address: nil,
        ipv6Address: nil,
        defaultGateway: nil,
        dnsServers: [],
        internetReachable: false,
        captivePortal: false
      )
    }
    guard
      let raw = SCDynamicStoreCopyMultiple(store, nil, Self.watchedNetworkPatterns as CFArray)
        as? [String: Any]
    else {
      return NetworkState(
        primaryInterface: nil,
        activeTunnelInterface: nil,
        activeTunnelInterfaces: [],
        primaryInterfaceIsTunnel: false,
        ipv4Address: nil,
        ipv6Address: nil,
        defaultGateway: nil,
        dnsServers: [],
        internetReachable: false,
        captivePortal: false
      )
    }

    var allInterfaces: [String] = []
    let globalIPv4 = raw["State:/Network/Global/IPv4"] as? [String: Any]
    let globalIPv6 = raw["State:/Network/Global/IPv6"] as? [String: Any]
    let globalDNS = raw["State:/Network/Global/DNS"] as? [String: Any]

    let primaryInterface =
      normalized(globalIPv4?["PrimaryInterface"] as? String)
      ?? normalized(globalIPv6?["PrimaryInterface"] as? String)

    let primaryServiceID =
      normalized(globalIPv4?["PrimaryService"] as? String)
      ?? normalized(globalIPv6?["PrimaryService"] as? String)

    if let primaryInterface {
      allInterfaces.append(primaryInterface)
    }

    for (key, value) in raw {
      guard key.hasPrefix("State:/Network/Service/") else { continue }
      guard key.hasSuffix("/IPv4") || key.hasSuffix("/IPv6") else { continue }
      guard
        let payload = value as? [String: Any],
        let interfaceName = normalized(payload["InterfaceName"] as? String)
      else {
        continue
      }

      if !allInterfaces.contains(interfaceName) {
        allInterfaces.append(interfaceName)
      }
    }

    let tunnelInterfaces = allInterfaces.filter(isTunnelInterface)
    let primaryInterfaceIsTunnel = primaryInterface.map(isTunnelInterface) ?? false
    let activeTunnelInterface = primaryInterfaceIsTunnel ? primaryInterface : nil
    let primaryIPv4 = primaryServiceID.flatMap {
      raw["State:/Network/Service/\($0)/IPv4"] as? [String: Any]
    }
    let primaryIPv6 = primaryServiceID.flatMap {
      raw["State:/Network/Service/\($0)/IPv6"] as? [String: Any]
    }
    let ipv4Address = firstString(in: primaryIPv4?["Addresses"])
    let ipv6Address = firstString(in: primaryIPv6?["Addresses"])
    let defaultGateway =
      normalized(globalIPv4?["Router"] as? String)
      ?? normalized(primaryIPv4?["Router"] as? String)
    let dnsServers = stringArray(in: globalDNS?["ServerAddresses"])
    let internetReachable = isInternetReachable()
    let captivePortal = !internetReachable && ipv4Address != nil && defaultGateway != nil

    return NetworkState(
      primaryInterface: primaryInterface,
      activeTunnelInterface: activeTunnelInterface,
      activeTunnelInterfaces: tunnelInterfaces,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      ipv4Address: ipv4Address,
      ipv6Address: ipv6Address,
      defaultGateway: defaultGateway,
      dnsServers: dnsServers,
      internetReachable: internetReachable,
      captivePortal: captivePortal
    )
  }

  /// Returns whether one interface name represents a tunnel.
  private func isTunnelInterface(_ name: String) -> Bool {
    name.hasPrefix("utun")
      || name.hasPrefix("ppp")
      || name.hasPrefix("ipsec")
      || name.hasPrefix("tap")
      || name.hasPrefix("tun")
  }

  /// Smooths RSSI so the UI does not jump on every sample.
  private func smoothedRSSIValue(from rssi: Int?) -> Int? {
    stateLock.lock()
    defer { stateLock.unlock() }

    guard let rssi else {
      smoothedRSSI = nil
      AgentLogger.debug("network RSSI unavailable")
      return nil
    }

    guard let smoothedRSSI else {
      smoothedRSSI = Double(rssi)
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
      ssidChangedAt: ssidChangedAt.map(Self.fieldDateFormatter.string(from:)),
      interfaceChangedAt: interfaceChangedAt.map(Self.fieldDateFormatter.string(from:))
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

  /// Returns whether the network looks internet-reachable.
  private func isInternetReachable() -> Bool {
    guard let reachability = SCNetworkReachabilityCreateWithName(nil, "1.1.1.1") else {
      return false
    }

    var flags = SCNetworkReachabilityFlags()
    guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
      return false
    }

    return flags.contains(.reachable) && !flags.contains(.connectionRequired)
  }

  /// Returns the first trimmed string from an array-like value.
  private func firstString(in value: Any?) -> String? {
    guard let values = value as? [String] else { return nil }
    return values.first.flatMap(normalized)
  }

  /// Returns a cleaned string array from an array-like value.
  private func stringArray(in value: Any?) -> [String] {
    guard let values = value as? [String] else { return [] }
    return values.compactMap(normalized)
  }

  /// Trims one optional string and drops empty values.
  private func normalized(_ value: String?) -> String? {
    guard let value else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
