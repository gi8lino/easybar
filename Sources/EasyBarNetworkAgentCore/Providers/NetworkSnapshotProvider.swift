import EasyBarShared
import Foundation

public final class NetworkSnapshotProvider {
  private let authorizer: NetworkLocationAuthorizer
  private let wifiMonitor: NetworkWiFiMonitor
  private let systemMonitor: NetworkSystemMonitor
  private let refreshIntervalSeconds: TimeInterval
  private let logger: ProcessLogger

  private var onChange: (() -> Void)?
  private var refreshTimer: Timer?

  /// Builds the network snapshot provider with one refresh interval.
  public init(
    refreshIntervalSeconds: TimeInterval,
    logger: ProcessLogger
  ) {
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.logger = logger
    authorizer = NetworkLocationAuthorizer(logger: logger)
    wifiMonitor = NetworkWiFiMonitor(logger: logger)
    systemMonitor = NetworkSystemMonitor(logger: logger)
  }

  /// Starts permission, Wi-Fi, and network monitoring.
  public func start(onChange: @escaping () -> Void) {
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

    logger.info("network agent refresh_interval_seconds=\(refreshIntervalSeconds)")

    if refreshIntervalSeconds > 0 {
      refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshIntervalSeconds, repeats: true) {
        [weak self] _ in
        self?.onChange?()
      }
    }

    onChange()
  }

  /// Stops timers and all active monitoring.
  public func stop() {
    refreshTimer?.invalidate()
    refreshTimer = nil

    authorizer.stop()
    wifiMonitor.stop()
    systemMonitor.stop()

    onChange = nil
  }

  /// Builds one network snapshot from current system state.
  public func snapshot() -> NetworkAgentSnapshot {
    let now = Date()
    let permissionState = authorizer.permissionState()
    let wifi = wifiMonitor.currentState(now: now)
    let network = systemMonitor.currentState()

    logger.debug(
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
  public func responseFields(
    for fields: [NetworkAgentField],
    allowUnauthorizedNonSensitiveFields: Bool
  ) -> (values: [String: NetworkAgentFieldValue]?, errorMessage: String?) {
    guard authorizer.isAuthorized() else {
      return unauthorizedFieldResponse(
        for: fields,
        allowUnauthorizedNonSensitiveFields: allowUnauthorizedNonSensitiveFields
      )
    }

    return (resolvedFieldValues(for: fields), nil)
  }

  /// Returns the requested field values for the current network state.
  private func resolvedFieldValues(for fields: [NetworkAgentField]) -> [String:
    NetworkAgentFieldValue]
  {
    let now = Date()
    let permissionState = authorizer.permissionState()
    let locationAuthorized = authorizer.isAuthorized()
    let wifi = wifiMonitor.currentState(now: now)
    let network = systemMonitor.currentState()

    var values: [String: NetworkAgentFieldValue] = [:]

    for field in fields {
      switch field {
      case .generatedAt:
        values[field.rawValue] = .string(NetworkWiFiSnapshot.fieldDateFormatter.string(from: now))

      case .ssid:
        if let ssid = wifi.ssid {
          values[field.rawValue] = .string(ssid)
        }

      case .bssid:
        if let bssid = wifi.bssid {
          values[field.rawValue] = .string(bssid)
        }

      case .interfaceName:
        if let interfaceName = wifi.interfaceName {
          values[field.rawValue] = .string(interfaceName)
        }

      case .hardwareAddress:
        if let hardwareAddress = wifi.hardwareAddress {
          values[field.rawValue] = .string(hardwareAddress)
        }

      case .power:
        if let power = wifi.power {
          values[field.rawValue] = .bool(power)
        }

      case .serviceActive:
        if let serviceActive = wifi.serviceActive {
          values[field.rawValue] = .bool(serviceActive)
        }

      case .primaryInterfaceIsTunnel:
        values[field.rawValue] = .bool(network.primaryInterfaceIsTunnel)

      case .rssi:
        if let rssi = wifi.rssi {
          values[field.rawValue] = .int(rssi)
        }

      case .noise:
        if let noise = wifi.noise {
          values[field.rawValue] = .int(noise)
        }

      case .snr:
        if let snr = wifi.snr {
          values[field.rawValue] = .int(snr)
        }

      case .linkQuality:
        if let linkQuality = wifi.linkQuality {
          values[field.rawValue] = .int(linkQuality)
        }

      case .txRate:
        if let txRate = wifi.txRate {
          values[field.rawValue] = .int(txRate)
        }

      case .channel:
        if let channel = wifi.channel {
          values[field.rawValue] = .int(channel)
        }

      case .channelBand:
        if let channelBand = wifi.channelBand {
          values[field.rawValue] = .string(channelBand)
        }

      case .channelWidth:
        if let channelWidth = wifi.channelWidth {
          values[field.rawValue] = .string(channelWidth)
        }

      case .security:
        if let security = wifi.security {
          values[field.rawValue] = .string(security)
        }

      case .phyMode:
        if let phyMode = wifi.phyMode {
          values[field.rawValue] = .string(phyMode)
        }

      case .interfaceMode:
        if let interfaceMode = wifi.interfaceMode {
          values[field.rawValue] = .string(interfaceMode)
        }

      case .countryCode:
        if let countryCode = wifi.countryCode {
          values[field.rawValue] = .string(countryCode)
        }

      case .roaming:
        values[field.rawValue] = .bool(wifi.roaming)

      case .ssidChangedAt:
        if let ssidChangedAt = wifi.ssidChangedAt {
          values[field.rawValue] = .string(ssidChangedAt)
        }

      case .interfaceChangedAt:
        if let interfaceChangedAt = wifi.interfaceChangedAt {
          values[field.rawValue] = .string(interfaceChangedAt)
        }

      case .primaryInterface:
        if let primaryInterface = network.primaryInterface {
          values[field.rawValue] = .string(primaryInterface)
        }

      case .activeTunnelInterface:
        if let activeTunnelInterface = network.activeTunnelInterface {
          values[field.rawValue] = .string(activeTunnelInterface)
        }

      case .activeTunnelInterfaces:
        values[field.rawValue] = .stringList(network.activeTunnelInterfaces)

      case .ipv4Address:
        if let ipv4Address = network.ipv4Address {
          values[field.rawValue] = .string(ipv4Address)
        }

      case .ipv6Address:
        if let ipv6Address = network.ipv6Address {
          values[field.rawValue] = .string(ipv6Address)
        }

      case .defaultGateway:
        if let defaultGateway = network.defaultGateway {
          values[field.rawValue] = .string(defaultGateway)
        }

      case .dnsServers:
        values[field.rawValue] = .stringList(network.dnsServers)

      case .internetReachable:
        values[field.rawValue] = .bool(network.internetReachable)

      case .captivePortal:
        values[field.rawValue] = .bool(network.captivePortal)

      case .locationAuthorized:
        values[field.rawValue] = .bool(locationAuthorized)

      case .locationPermissionState:
        values[field.rawValue] = .string(permissionState)
      }
    }

    return values
  }

  /// Returns the unauthorized response for one requested field list.
  private func unauthorizedFieldResponse(
    for fields: [NetworkAgentField],
    allowUnauthorizedNonSensitiveFields: Bool
  ) -> (values: [String: NetworkAgentFieldValue]?, errorMessage: String?) {
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
