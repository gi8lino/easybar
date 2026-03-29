import CoreLocation
import CoreWLAN
import EasyBarShared
import Foundation
import SystemConfiguration

final class NetworkSnapshotProvider: NSObject, CLLocationManagerDelegate, CWEventDelegate {
  private let locationManager = CLLocationManager()
  private let authState = NetworkAgentAuthorizationState()
  private let smoothingFactor = 0.35
  private let refreshIntervalSeconds: TimeInterval

  private var onChange: (() -> Void)?
  private var wifiClient: CWWiFiClient?
  private var refreshTimer: Timer?
  private var smoothedRSSI: Double?

  private var store: SCDynamicStore?
  private var storeSource: CFRunLoopSource?

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

    guard authState.isAuthorized() else {
      return NetworkAgentSnapshot(
        accessGranted: false,
        permissionState: permissionState,
        generatedAt: now,
        ssid: nil,
        interfaceName: nil,
        primaryInterfaceIsTunnel: currentPrimaryInterface().map(isTunnelInterface) ?? false,
        rssi: nil
      )
    }

    let interface = CWWiFiClient.shared().interface()
    let ssid = normalized(interface?.ssid())
    let interfaceName = normalized(interface?.interfaceName)
    let rssi = validMeasurement(interface?.rssiValue())
    let displayRSSI = smoothedRSSIValue(from: rssi)
    let primaryInterfaceIsTunnel = currentPrimaryInterface().map(isTunnelInterface) ?? false

    AgentLogger.debug(
      "network snapshot access_granted=true permission_state=\(permissionState) ssid=\(ssid ?? "<none>") interface=\(interfaceName ?? "<none>") rssi=\(displayRSSI.map(String.init) ?? "<none>") primary_is_tunnel=\(primaryInterfaceIsTunnel)"
    )

    return NetworkAgentSnapshot(
      accessGranted: true,
      permissionState: permissionState,
      generatedAt: now,
      ssid: ssid,
      interfaceName: interfaceName,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      rssi: displayRSSI
    )
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

    let patterns: [CFString] = [
      "State:/Network/Global/IPv4" as CFString,
      "State:/Network/Global/IPv6" as CFString,
    ]

    SCDynamicStoreSetNotificationKeys(store, nil, patterns as CFArray)

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

  /// Returns the current primary network interface name.
  private func currentPrimaryInterface() -> String? {
    guard let store else { return nil }

    let globalIPv4 =
      SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any]
    let globalIPv6 =
      SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv6" as CFString) as? [String: Any]

    return normalized(globalIPv4?["PrimaryInterface"] as? String)
      ?? normalized(globalIPv6?["PrimaryInterface"] as? String)
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

  /// Filters out unusable measurements from system APIs.
  private func validMeasurement(_ value: Int?) -> Int? {
    guard let value, value != 0 else { return nil }
    return value
  }

  /// Trims one optional string and drops empty values.
  private func normalized(_ value: String?) -> String? {
    guard let value else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
