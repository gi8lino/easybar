import EasyBarShared
import Foundation

/// Provides authorization-aware network snapshots.
public final class NetworkSnapshotProvider: @unchecked Sendable {
  /// Immutable values used while resolving requested field values.
  private struct FieldResolutionContext {
    let now: Date
    let permissionState: String
    let locationAuthorized: Bool
    let wifi: NetworkWiFiSnapshot
    let network: NetworkSystemSnapshot
  }

  private let componentName: String
  private let authorizer: NetworkLocationAuthorizationController
  private let wifiMonitor: NetworkWiFiMonitor
  private let systemMonitor: NetworkSystemMonitor
  private let refreshIntervalSeconds: TimeInterval
  private let logger: ProcessLogger

  private var onChange: (() -> Void)?
  private var refreshTimer: Timer?

  /// Builds the network snapshot provider with one refresh interval.
  public init(
    componentName: String,
    refreshIntervalSeconds: TimeInterval,
    logger: ProcessLogger,
    promptPresenter: NetworkAuthorizationPromptPresenter? = nil
  ) {
    self.componentName = componentName
    self.refreshIntervalSeconds = refreshIntervalSeconds
    self.logger = logger
    authorizer = NetworkLocationAuthorizationController(
      componentName: componentName,
      logger: logger.child("authorization"),
      promptPresenter: promptPresenter
    )
    wifiMonitor = NetworkWiFiMonitor(
      componentName: componentName, logger: logger.child("wifi_monitor"))
    systemMonitor = NetworkSystemMonitor(
      componentName: componentName, logger: logger.child("system_monitor"))
  }

  /// Starts permission, Wi-Fi, and network monitoring.
  public func start(onChange: @escaping () -> Void) {
    stop()
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

    logger.info(
      "\(componentName) refresh",
      .field("interval_seconds", refreshIntervalSeconds),
    )

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
      "\(componentName) snapshot",
      .field("access_granted", authorizer.isAuthorized()),
      .field("permission_state", permissionState),
      .field("ssid", wifi.ssid ?? "<none>"),
      .field("interface", wifi.interfaceName ?? "<none>"),
      .field("ipv4_address", network.ipv4Address ?? "<none>"),
      .field("ipv6_address", network.ipv6Address ?? "<none>"),
      .field("rssi", wifi.rssi.map(String.init) ?? "<none>"),
      .field("primary_is_tunnel", network.primaryInterfaceIsTunnel),
    )

    return NetworkAgentSnapshot(
      accessGranted: authorizer.isAuthorized(),
      permissionState: permissionState,
      generatedAt: now,
      ssid: wifi.ssid,
      ipv4Address: network.ipv4Address,
      ipv6Address: network.ipv6Address,
      bssid: wifi.bssid,
      interfaceName: wifi.interfaceName,
      hardwareAddress: wifi.hardwareAddress,
      power: wifi.power,
      serviceActive: wifi.serviceActive,
      primaryInterfaceIsTunnel: network.primaryInterfaceIsTunnel,
      rssi: wifi.rssi,
      noise: wifi.noise,
      snr: wifi.snr,
      linkQuality: wifi.linkQuality,
      txRate: wifi.txRate,
      channel: wifi.channel,
      channelBand: wifi.channelBand,
      channelWidth: wifi.channelWidth,
      security: wifi.security,
      phyMode: wifi.phyMode,
      interfaceMode: wifi.interfaceMode,
      countryCode: wifi.countryCode,
      roaming: wifi.roaming,
      ssidChangedAt: wifi.ssidChangedAt,
      interfaceChangedAt: wifi.interfaceChangedAt
    )
  }

  /// Returns the requested field values, applying the current privacy policy.
  public func responseFields(
    for fields: [NetworkAgentField],
    allowUnauthorizedFieldsWithoutLocation: Bool
  ) -> (values: [String: NetworkAgentFieldValue]?, errorCode: NetworkAgentErrorCode?) {
    guard authorizer.isAuthorized() else {
      return unauthorizedFieldResponse(
        for: fields,
        allowUnauthorizedFieldsWithoutLocation: allowUnauthorizedFieldsWithoutLocation
      )
    }

    return (resolvedFieldValues(for: fields), nil)
  }

  /// Returns the requested field values for the current network state.
  private func resolvedFieldValues(for fields: [NetworkAgentField]) -> [String:
    NetworkAgentFieldValue]
  {
    let context = fieldResolutionContext()
    var values: [String: NetworkAgentFieldValue] = [:]

    for field in fields {
      guard let value = fieldValue(for: field, context: context) else { continue }
      values[field.rawValue] = value
    }

    return values
  }

  /// Captures a consistent set of values for one field-response build.
  private func fieldResolutionContext() -> FieldResolutionContext {
    let now = Date()
    return FieldResolutionContext(
      now: now,
      permissionState: authorizer.permissionState(),
      locationAuthorized: authorizer.isAuthorized(),
      wifi: wifiMonitor.currentState(now: now),
      network: systemMonitor.currentState()
    )
  }

  /// Resolves one requested field from the current context.
  private func fieldValue(
    for field: NetworkAgentField,
    context: FieldResolutionContext
  ) -> NetworkAgentFieldValue? {
    switch field {
    case .generatedAt:
      return .string(NetworkAgentSnapshot.dateString(from: context.now))
    case .ssid, .bssid, .interfaceName, .hardwareAddress, .power, .serviceActive, .rssi,
      .noise, .snr, .linkQuality, .txRate, .channel, .channelBand, .channelWidth, .security,
      .phyMode, .interfaceMode, .countryCode, .roaming, .ssidChangedAt, .interfaceChangedAt:
      return wifiFieldValue(for: field, wifi: context.wifi)
    case .primaryInterfaceIsTunnel, .primaryInterface, .activeTunnelInterface,
      .activeTunnelInterfaces, .ipv4Address, .ipv6Address, .defaultGateway, .dnsServers,
      .internetReachable, .captivePortal:
      return networkFieldValue(for: field, network: context.network)
    case .locationAuthorized, .locationPermissionState:
      return authorizationFieldValue(for: field, context: context)
    }
  }

  /// Resolves one Wi-Fi field value.
  private func wifiFieldValue(
    for field: NetworkAgentField,
    wifi: NetworkWiFiSnapshot
  ) -> NetworkAgentFieldValue? {
    switch field {
    case .ssid:
      return wifi.ssid.map(NetworkAgentFieldValue.string)
    case .bssid:
      return wifi.bssid.map(NetworkAgentFieldValue.string)
    case .interfaceName:
      return wifi.interfaceName.map(NetworkAgentFieldValue.string)
    case .hardwareAddress:
      return wifi.hardwareAddress.map(NetworkAgentFieldValue.string)
    case .power:
      return wifi.power.map(NetworkAgentFieldValue.bool)
    case .serviceActive:
      return wifi.serviceActive.map(NetworkAgentFieldValue.bool)
    case .rssi:
      return wifi.rssi.map(NetworkAgentFieldValue.int)
    case .noise:
      return wifi.noise.map(NetworkAgentFieldValue.int)
    case .snr:
      return wifi.snr.map(NetworkAgentFieldValue.int)
    case .linkQuality:
      return wifi.linkQuality.map(NetworkAgentFieldValue.int)
    case .txRate:
      return wifi.txRate.map(NetworkAgentFieldValue.int)
    case .channel:
      return wifi.channel.map(NetworkAgentFieldValue.int)
    case .channelBand:
      return wifi.channelBand.map(NetworkAgentFieldValue.string)
    case .channelWidth:
      return wifi.channelWidth.map(NetworkAgentFieldValue.string)
    case .security:
      return wifi.security.map(NetworkAgentFieldValue.string)
    case .phyMode:
      return wifi.phyMode.map(NetworkAgentFieldValue.string)
    case .interfaceMode:
      return wifi.interfaceMode.map(NetworkAgentFieldValue.string)
    case .countryCode:
      return wifi.countryCode.map(NetworkAgentFieldValue.string)
    case .roaming:
      return .bool(wifi.roaming)
    case .ssidChangedAt:
      return wifi.ssidChangedAt.map(NetworkAgentFieldValue.string)
    case .interfaceChangedAt:
      return wifi.interfaceChangedAt.map(NetworkAgentFieldValue.string)
    default:
      return nil
    }
  }

  /// Resolves one generic network field value.
  private func networkFieldValue(
    for field: NetworkAgentField,
    network: NetworkSystemSnapshot
  ) -> NetworkAgentFieldValue? {
    switch field {
    case .primaryInterfaceIsTunnel:
      return .bool(network.primaryInterfaceIsTunnel)
    case .primaryInterface:
      return network.primaryInterface.map(NetworkAgentFieldValue.string)
    case .activeTunnelInterface:
      return network.activeTunnelInterface.map(NetworkAgentFieldValue.string)
    case .activeTunnelInterfaces:
      return .stringList(network.activeTunnelInterfaces)
    case .ipv4Address:
      return network.ipv4Address.map(NetworkAgentFieldValue.string)
    case .ipv6Address:
      return network.ipv6Address.map(NetworkAgentFieldValue.string)
    case .defaultGateway:
      return network.defaultGateway.map(NetworkAgentFieldValue.string)
    case .dnsServers:
      return .stringList(network.dnsServers)
    case .internetReachable:
      return .bool(network.internetReachable)
    case .captivePortal:
      return .bool(network.captivePortal)
    default:
      return nil
    }
  }

  /// Resolves one authorization field value.
  private func authorizationFieldValue(
    for field: NetworkAgentField,
    context: FieldResolutionContext
  ) -> NetworkAgentFieldValue? {
    switch field {
    case .locationAuthorized:
      return .bool(context.locationAuthorized)
    case .locationPermissionState:
      return .string(context.permissionState)
    default:
      return nil
    }
  }

  /// Returns the unauthorized response for one requested field list.
  private func unauthorizedFieldResponse(
    for fields: [NetworkAgentField],
    allowUnauthorizedFieldsWithoutLocation: Bool
  ) -> (values: [String: NetworkAgentFieldValue]?, errorCode: NetworkAgentErrorCode?) {
    let hasLocationProtectedFields = fields.contains(where: fieldRequiresLocationAuthorization)

    guard hasLocationProtectedFields else {
      return (resolvedFieldValues(for: fields), nil)
    }

    guard allowUnauthorizedFieldsWithoutLocation else {
      return (nil, .permissionDenied)
    }

    let allowedFields = fields.filter { !fieldRequiresLocationAuthorization($0) }
    guard !allowedFields.isEmpty else {
      return (nil, .permissionDenied)
    }

    return (resolvedFieldValues(for: allowedFields), nil)
  }

  /// Returns whether the field should be hidden without location authorization.
  private func fieldRequiresLocationAuthorization(_ field: NetworkAgentField) -> Bool {
    networkAgentFieldRequiresLocationAuthorization(field)
  }
}
