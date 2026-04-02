import EasyBarShared
import Foundation

final class NetworkSnapshotProvider {
  private let authorizer = NetworkLocationAuthorizer()
  private let wifiMonitor = NetworkWiFiMonitor()
  private let systemMonitor = NetworkSystemMonitor()
  private let refreshIntervalSeconds: TimeInterval

  private var onChange: (() -> Void)?
  private var refreshTimer: Timer?

  /// Builds the network snapshot provider with one refresh interval.
  init(refreshIntervalSeconds: TimeInterval) {
    self.refreshIntervalSeconds = refreshIntervalSeconds
  }

  /// Starts permission, Wi-Fi, and network monitoring.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    authorizer.start { [weak self] in
      self?.onChange?()
    }

    wifiMonitor.start { [weak self] in
      self?.onChange?()
    }

    systemMonitor.start { [weak self] in
      self?.onChange?()
    }

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

    authorizer.stop()
    wifiMonitor.stop()
    systemMonitor.stop()

    onChange = nil
  }

  /// Builds one network snapshot from current system state.
  func snapshot() -> NetworkAgentSnapshot {
    let now = Date()
    let permissionState = authorizer.permissionState()
    let wifi = wifiMonitor.currentState(now: now)
    let network = systemMonitor.currentState()

    AgentLogger.debug(
      "network snapshot access_granted=\(authorizer.isAuthorized()) permission_state=\(permissionState) ssid=\(wifi.ssid ?? "<none>") interface=\(wifi.interfaceName ?? "<none>") rssi=\(wifi.rssi.map(String.init) ?? "<none>") primary_is_tunnel=\(network.primaryInterfaceIsTunnel)"
    )

    return NetworkAgentSnapshot(
      accessGranted: authorizer.isAuthorized(),
      permissionState: permissionState,
      generatedAt: now,
      ssid: wifi.ssid,
      interfaceName: wifi.interfaceName,
      primaryInterfaceIsTunnel: network.primaryInterfaceIsTunnel,
      rssi: wifi.rssi
    )
  }

  /// Returns the requested field values, applying the current privacy policy.
  func responseFields(
    for fields: [NetworkAgentField],
    allowUnauthorizedNonSensitiveFields: Bool
  ) -> (values: [String: String]?, errorMessage: String?) {
    guard authorizer.isAuthorized() else {
      return unauthorizedFieldResponse(
        for: fields,
        allowUnauthorizedNonSensitiveFields: allowUnauthorizedNonSensitiveFields
      )
    }

    return (resolvedFieldValues(for: fields), nil)
  }

  /// Returns the requested field values for the current network state.
  private func resolvedFieldValues(for fields: [NetworkAgentField]) -> [String: String] {
    let now = Date()
    let permissionState = authorizer.permissionState()
    let locationAuthorized = authorizer.isAuthorized()
    let wifi = wifiMonitor.currentState(now: now)
    let network = systemMonitor.currentState()

    var values: [String: String] = [:]

    for field in fields {
      switch field {
      case .generatedAt:
        values[field.rawValue] = NetworkWiFiSnapshot.fieldDateFormatter.string(from: now)

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

  /// Returns the unauthorized response for one requested field list.
  private func unauthorizedFieldResponse(
    for fields: [NetworkAgentField],
    allowUnauthorizedNonSensitiveFields: Bool
  ) -> (values: [String: String]?, errorMessage: String?) {
    let permissionState = authorizer.permissionState()
    let hasPermissionGatedFields = fields.contains(where: requiresLocationAuthorization)

    guard hasPermissionGatedFields else {
      return (resolvedFieldValues(for: fields), nil)
    }

    guard allowUnauthorizedNonSensitiveFields else {
      return (nil, "permission_denied:\(permissionState)")
    }

    let allowedFields = fields.filter { !requiresLocationAuthorization($0) }
    guard !allowedFields.isEmpty else {
      return (nil, "permission_denied:\(permissionState)")
    }

    return (resolvedFieldValues(for: allowedFields), nil)
  }

  /// Returns whether the field should be hidden without location authorization.
  private func requiresLocationAuthorization(_ field: NetworkAgentField) -> Bool {
    field.rawValue.hasPrefix("wifi.")
  }
}
