import Foundation

/// Stable protocol version used by the network agent socket.
public let networkAgentProtocolVersion = "1"

/// Commands supported by the network agent socket.
public enum NetworkAgentCommand: String, Codable {
  case ping
  case version
  case fetch
  case subscribe
}

/// Field keys supported by the network agent.
public enum NetworkAgentField: String, Codable, CaseIterable {
  case generatedAt = "network.generated_at"
  case ssid = "wifi.ssid"
  case bssid = "wifi.bssid"
  case interfaceName = "wifi.interface"
  case hardwareAddress = "wifi.hardware_address"
  case power = "wifi.power"
  case serviceActive = "wifi.service_active"
  case primaryInterfaceIsTunnel = "network.primary_interface_is_tunnel"
  case rssi = "wifi.rssi"
  case noise = "wifi.noise"
  case snr = "wifi.snr"
  case linkQuality = "wifi.link_quality"
  case txRate = "wifi.tx_rate"
  case channel = "wifi.channel"
  case channelBand = "wifi.channel_band"
  case channelWidth = "wifi.channel_width"
  case security = "wifi.security"
  case phyMode = "wifi.phy_mode"
  case interfaceMode = "wifi.interface_mode"
  case countryCode = "wifi.country_code"
  case roaming = "wifi.roaming"
  case ssidChangedAt = "wifi.ssid_changed_at"
  case interfaceChangedAt = "wifi.interface_changed_at"
  case primaryInterface = "network.primary_interface"
  case activeTunnelInterface = "network.active_tunnel_interface"
  case activeTunnelInterfaces = "network.active_tunnel_interfaces"
  case ipv4Address = "network.ipv4_address"
  case ipv6Address = "network.ipv6_address"
  case defaultGateway = "network.default_gateway"
  case dnsServers = "network.dns_servers"
  case internetReachable = "network.internet_reachable"
  case captivePortal = "network.captive_portal"
  case locationAuthorized = "auth.location_authorized"
  case locationPermissionState = "auth.location_permission_state"
}

/// Stable field namespaces supported by the network agent.
public enum NetworkAgentFieldNamespace: String, Codable, CaseIterable {
  case wifi
  case network
  case auth

  /// Prefix shared by every field in this namespace.
  public var fieldPrefix: String {
    return rawValue + "."
  }

  /// Returns whether the namespace contains the provided field.
  public func contains(_ field: NetworkAgentField) -> Bool {
    return field.rawValue.hasPrefix(fieldPrefix)
  }
}

/// One stable wire-level error code returned by the network agent.
public enum NetworkAgentErrorCode: String, Codable, Equatable {
  case permissionDenied = "permission_denied"
  case missingFields = "missing_fields"
  case providerUnavailable = "provider_unavailable"
  case unknown = "unknown"
}

/// Describes one shared network-agent field.
public struct NetworkAgentFieldSpec {
  /// Field key used on the wire.
  public let field: NetworkAgentField
  /// Short help text for humans.
  public let help: String
  /// Whether the field requires location authorization.
  public let requiresLocationAuthorization: Bool

  /// Creates one network-agent field spec.
  public init(
    field: NetworkAgentField,
    help: String,
    requiresLocationAuthorization: Bool = false
  ) {
    self.field = field
    self.help = help
    self.requiresLocationAuthorization = requiresLocationAuthorization
  }
}

/// Describes one shared network-agent namespace selector.
public struct NetworkAgentFieldNamespaceSpec {
  /// Namespace key accepted by clients.
  public let namespace: NetworkAgentFieldNamespace
  /// Short help text for humans.
  public let help: String

  /// Creates one shared network-agent namespace selector.
  public init(namespace: NetworkAgentFieldNamespace, help: String) {
    self.namespace = namespace
    self.help = help
  }
}

/// Ordered network-agent field metadata shared by clients and the agent.
public let networkAgentFieldRegistry: [NetworkAgentFieldSpec] = [
  .init(field: .ssid, help: "Current Wi-Fi network name", requiresLocationAuthorization: true),
  .init(field: .bssid, help: "Current access point BSSID", requiresLocationAuthorization: true),
  .init(field: .interfaceName, help: "Wi-Fi interface name", requiresLocationAuthorization: true),
  .init(
    field: .hardwareAddress,
    help: "Wi-Fi hardware MAC address",
    requiresLocationAuthorization: true
  ),
  .init(field: .power, help: "Wi-Fi power state", requiresLocationAuthorization: true),
  .init(
    field: .serviceActive,
    help: "CoreWLAN service availability",
    requiresLocationAuthorization: true
  ),
  .init(field: .rssi, help: "Received signal strength", requiresLocationAuthorization: true),
  .init(field: .noise, help: "Noise floor", requiresLocationAuthorization: true),
  .init(field: .snr, help: "Signal-to-noise ratio", requiresLocationAuthorization: true),
  .init(
    field: .linkQuality,
    help: "Derived link quality percent",
    requiresLocationAuthorization: true
  ),
  .init(field: .txRate, help: "Transmit rate in Mbps", requiresLocationAuthorization: true),
  .init(field: .channel, help: "Current Wi-Fi channel", requiresLocationAuthorization: true),
  .init(field: .channelBand, help: "Channel band label", requiresLocationAuthorization: true),
  .init(field: .channelWidth, help: "Channel width label", requiresLocationAuthorization: true),
  .init(field: .security, help: "Current security mode", requiresLocationAuthorization: true),
  .init(field: .phyMode, help: "PHY mode label", requiresLocationAuthorization: true),
  .init(field: .interfaceMode, help: "Interface mode label", requiresLocationAuthorization: true),
  .init(field: .countryCode, help: "Current country code", requiresLocationAuthorization: true),
  .init(field: .roaming, help: "Roaming state", requiresLocationAuthorization: true),
  .init(
    field: .ssidChangedAt,
    help: "Last SSID change time",
    requiresLocationAuthorization: true
  ),
  .init(
    field: .interfaceChangedAt,
    help: "Last interface change time",
    requiresLocationAuthorization: true
  ),
  .init(field: .primaryInterface, help: "Primary network interface"),
  .init(field: .activeTunnelInterface, help: "First active tunnel interface"),
  .init(field: .activeTunnelInterfaces, help: "All active tunnel interfaces"),
  .init(field: .primaryInterfaceIsTunnel, help: "Whether the primary interface is a tunnel"),
  .init(field: .ipv4Address, help: "Primary IPv4 address"),
  .init(field: .ipv6Address, help: "Primary IPv6 address"),
  .init(field: .defaultGateway, help: "Default gateway address"),
  .init(field: .dnsServers, help: "Configured DNS servers"),
  .init(field: .internetReachable, help: "Internet reachability state"),
  .init(field: .captivePortal, help: "Captive portal state"),
  .init(field: .locationAuthorized, help: "Location authorization state"),
  .init(field: .locationPermissionState, help: "Location permission label"),
  .init(field: .generatedAt, help: "Snapshot generation time"),
]

/// Ordered namespace selectors shared by clients.
public let networkAgentFieldNamespaceRegistry: [NetworkAgentFieldNamespaceSpec] = [
  .init(namespace: .wifi, help: "Expand to every Wi-Fi field"),
  .init(namespace: .network, help: "Expand to every network field"),
  .init(namespace: .auth, help: "Expand to every authorization field"),
]

/// One selector-expansion error shared by clients.
public enum NetworkAgentFieldSelectorError: LocalizedError, Equatable {
  case unknownFieldOrSelector(String)

  /// Returns the localized selector error message.
  public var errorDescription: String? {
    switch self {
    case .unknownFieldOrSelector(let value):
      return "unknown field or selector: \(value)"
    }
  }
}

/// Network-agent field metadata keyed by field.
public let networkAgentFieldSpecsByField = Dictionary(
  uniqueKeysWithValues: networkAgentFieldRegistry.map { ($0.field, $0) }
)

private let networkAgentFieldsInRegistryOrder = networkAgentFieldRegistry.map(\.field)
private let networkAgentFieldsByRawValue = Dictionary(
  uniqueKeysWithValues: networkAgentFieldsInRegistryOrder.map { ($0.rawValue, $0) }
)

/// Returns the registry descriptor for one network-agent field.
public func networkAgentFieldSpec(for field: NetworkAgentField) -> NetworkAgentFieldSpec? {
  networkAgentFieldSpecsByField[field]
}

/// Returns whether one network-agent field requires location authorization.
public func networkAgentFieldRequiresLocationAuthorization(_ field: NetworkAgentField) -> Bool {
  networkAgentFieldSpec(for: field)?.requiresLocationAuthorization ?? false
}

/// Expands field names and shared selectors into concrete fields.
public func expandNetworkAgentFieldSelectors(_ selectors: [String]) throws -> [NetworkAgentField] {
  var expanded: [NetworkAgentField] = []
  var seen: Set<NetworkAgentField> = []

  for selector in selectors.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({
    !$0.isEmpty
  }) {
    for field in try expandNetworkAgentFieldSelector(selector) {
      if seen.insert(field).inserted {
        expanded.append(field)
      }
    }
  }

  return expanded
}

/// Expands one field name or selector into concrete fields.
public func expandNetworkAgentFieldSelector(_ selector: String) throws -> [NetworkAgentField] {
  if selector == "all" {
    return networkAgentFieldsInRegistryOrder
  }

  if let field = networkAgentFieldsByRawValue[selector] {
    return [field]
  }

  guard let namespace = networkAgentFieldNamespace(for: selector) else {
    throw NetworkAgentFieldSelectorError.unknownFieldOrSelector(selector)
  }

  return networkAgentFieldsInRegistryOrder.filter(namespace.contains)
}

/// Handles network agent field namespace.
private func networkAgentFieldNamespace(for selector: String) -> NetworkAgentFieldNamespace? {
  if let namespace = NetworkAgentFieldNamespace(rawValue: selector) {
    return namespace
  }

  if selector.hasSuffix("."),
    let namespace = NetworkAgentFieldNamespace(rawValue: String(selector.dropLast()))
  {
    return namespace
  }

  if selector.hasSuffix(".*"),
    let namespace = NetworkAgentFieldNamespace(rawValue: String(selector.dropLast(2)))
  {
    return namespace
  }

  return nil
}

/// One request sent to the network agent.
public struct NetworkAgentRequest: Codable {
  /// Command to execute on the agent.
  public var command: NetworkAgentCommand
  /// Requested field keys for fetch and subscribe.
  public var fields: [NetworkAgentField]?

  /// Creates one network agent request.
  public init(command: NetworkAgentCommand, fields: [NetworkAgentField]? = nil) {
    self.command = command
    self.fields = fields
  }

  /// Builds one fetch request.
  public static func fetch(_ fields: [NetworkAgentField]) -> Self {
    return Self(command: .fetch, fields: fields)
  }

  /// Builds one subscribe request.
  public static func subscribe(_ fields: [NetworkAgentField]) -> Self {
    return Self(command: .subscribe, fields: fields)
  }
}

/// One version payload returned by the network agent.
public struct NetworkAgentVersion: Codable, Equatable {
  /// The application version embedded in the network-agent build.
  public var appVersion: String
  /// Stable socket protocol version.
  public var protocolVersion: String

  /// Creates one network-agent version payload.
  public init(appVersion: String, protocolVersion: String) {
    self.appVersion = appVersion
    self.protocolVersion = protocolVersion
  }
}

/// Full network snapshot returned by the agent.
public struct NetworkAgentSnapshot: Codable, Equatable {
  public static let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  /// Standard field set required to build a snapshot from field values.
  public static let snapshotFieldSet: [NetworkAgentField] = [
    .locationAuthorized,
    .locationPermissionState,
    .generatedAt,
    .ssid,
    .ipv4Address,
    .ipv6Address,
    .bssid,
    .interfaceName,
    .hardwareAddress,
    .power,
    .serviceActive,
    .primaryInterfaceIsTunnel,
    .rssi,
    .noise,
    .snr,
    .linkQuality,
    .txRate,
    .channel,
    .channelBand,
    .channelWidth,
    .security,
    .phyMode,
    .interfaceMode,
    .countryCode,
    .roaming,
    .ssidChangedAt,
    .interfaceChangedAt,
  ]

  /// Whether location/Wi-Fi access is currently granted.
  public var accessGranted: Bool
  /// Current permission state string.
  public var permissionState: String
  /// Snapshot generation time.
  public var generatedAt: Date
  /// Active Wi-Fi SSID when available.
  public var ssid: String?
  /// Primary network IPv4 address when available.
  public var ipv4Address: String?
  /// Primary network IPv6 address when available.
  public var ipv6Address: String?
  /// Active Wi-Fi BSSID when available.
  public var bssid: String?
  /// Active Wi-Fi interface name when available.
  public var interfaceName: String?
  /// Active Wi-Fi hardware address when available.
  public var hardwareAddress: String?
  /// Wi-Fi power state when available.
  public var power: Bool?
  /// Wi-Fi service availability when available.
  public var serviceActive: Bool?
  /// Whether the current primary interface is a tunnel.
  public var primaryInterfaceIsTunnel: Bool
  /// Raw or smoothed RSSI value when available.
  public var rssi: Int?
  /// Noise floor when available.
  public var noise: Int?
  /// Signal-to-noise ratio when available.
  public var snr: Int?
  /// Link quality percentage when available.
  public var linkQuality: Int?
  /// Current transmit rate when available.
  public var txRate: Int?
  /// Current Wi-Fi channel when available.
  public var channel: Int?
  /// Current Wi-Fi band when available.
  public var channelBand: String?
  /// Current Wi-Fi channel width when available.
  public var channelWidth: String?
  /// Current Wi-Fi security mode when available.
  public var security: String?
  /// Current Wi-Fi PHY mode when available.
  public var phyMode: String?
  /// Current Wi-Fi interface mode when available.
  public var interfaceMode: String?
  /// Current Wi-Fi country code when available.
  public var countryCode: String?
  /// Whether roaming was detected when available.
  public var roaming: Bool?
  /// Last SSID change timestamp when available.
  public var ssidChangedAt: String?
  /// Last interface change timestamp when available.
  public var interfaceChangedAt: String?

  /// Creates one network snapshot payload.
  public init(
    accessGranted: Bool,
    permissionState: String,
    generatedAt: Date,
    ssid: String?,
    ipv4Address: String?,
    ipv6Address: String?,
    bssid: String?,
    interfaceName: String?,
    hardwareAddress: String?,
    power: Bool?,
    serviceActive: Bool?,
    primaryInterfaceIsTunnel: Bool,
    rssi: Int?,
    noise: Int?,
    snr: Int?,
    linkQuality: Int?,
    txRate: Int?,
    channel: Int?,
    channelBand: String?,
    channelWidth: String?,
    security: String?,
    phyMode: String?,
    interfaceMode: String?,
    countryCode: String?,
    roaming: Bool?,
    ssidChangedAt: String?,
    interfaceChangedAt: String?
  ) {
    self.accessGranted = accessGranted
    self.permissionState = permissionState
    self.generatedAt = generatedAt
    self.ssid = ssid
    self.ipv4Address = ipv4Address
    self.ipv6Address = ipv6Address
    self.bssid = bssid
    self.interfaceName = interfaceName
    self.hardwareAddress = hardwareAddress
    self.power = power
    self.serviceActive = serviceActive
    self.primaryInterfaceIsTunnel = primaryInterfaceIsTunnel
    self.rssi = rssi
    self.noise = noise
    self.snr = snr
    self.linkQuality = linkQuality
    self.txRate = txRate
    self.channel = channel
    self.channelBand = channelBand
    self.channelWidth = channelWidth
    self.security = security
    self.phyMode = phyMode
    self.interfaceMode = interfaceMode
    self.countryCode = countryCode
    self.roaming = roaming
    self.ssidChangedAt = ssidChangedAt
    self.interfaceChangedAt = interfaceChangedAt
  }

  /// Builds one typed snapshot from field-query values.
  public init?(fields: [String: NetworkAgentFieldValue]) {
    guard
      let accessGranted = fields[NetworkAgentField.locationAuthorized.rawValue]?.boolValue,
      let permissionState = fields[NetworkAgentField.locationPermissionState.rawValue]?.stringValue,
      let generatedAtRaw = fields[NetworkAgentField.generatedAt.rawValue]?.stringValue,
      let generatedAt = Self.dateFormatter.date(from: generatedAtRaw),
      let primaryInterfaceIsTunnel = fields[NetworkAgentField.primaryInterfaceIsTunnel.rawValue]?
        .boolValue
    else {
      return nil
    }

    self.init(
      accessGranted: accessGranted,
      permissionState: permissionState,
      generatedAt: generatedAt,
      ssid: fields[NetworkAgentField.ssid.rawValue]?.stringValue,
      ipv4Address: fields[NetworkAgentField.ipv4Address.rawValue]?.stringValue,
      ipv6Address: fields[NetworkAgentField.ipv6Address.rawValue]?.stringValue,
      bssid: fields[NetworkAgentField.bssid.rawValue]?.stringValue,
      interfaceName: fields[NetworkAgentField.interfaceName.rawValue]?.stringValue,
      hardwareAddress: fields[NetworkAgentField.hardwareAddress.rawValue]?.stringValue,
      power: fields[NetworkAgentField.power.rawValue]?.boolValue,
      serviceActive: fields[NetworkAgentField.serviceActive.rawValue]?.boolValue,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      rssi: fields[NetworkAgentField.rssi.rawValue]?.intValue,
      noise: fields[NetworkAgentField.noise.rawValue]?.intValue,
      snr: fields[NetworkAgentField.snr.rawValue]?.intValue,
      linkQuality: fields[NetworkAgentField.linkQuality.rawValue]?.intValue,
      txRate: fields[NetworkAgentField.txRate.rawValue]?.intValue,
      channel: fields[NetworkAgentField.channel.rawValue]?.intValue,
      channelBand: fields[NetworkAgentField.channelBand.rawValue]?.stringValue,
      channelWidth: fields[NetworkAgentField.channelWidth.rawValue]?.stringValue,
      security: fields[NetworkAgentField.security.rawValue]?.stringValue,
      phyMode: fields[NetworkAgentField.phyMode.rawValue]?.stringValue,
      interfaceMode: fields[NetworkAgentField.interfaceMode.rawValue]?.stringValue,
      countryCode: fields[NetworkAgentField.countryCode.rawValue]?.stringValue,
      roaming: fields[NetworkAgentField.roaming.rawValue]?.boolValue,
      ssidChangedAt: fields[NetworkAgentField.ssidChangedAt.rawValue]?.stringValue,
      interfaceChangedAt: fields[NetworkAgentField.interfaceChangedAt.rawValue]?.stringValue
    )
  }
}

/// Message kinds sent by the network agent.
public enum NetworkAgentMessageKind: String, Codable {
  case pong
  case version
  case subscribed
  case fields
  case error
}

/// One message sent over the network agent socket.
public struct NetworkAgentMessage: Codable {
  /// Message kind discriminator.
  public var kind: NetworkAgentMessageKind
  /// Optional version payload.
  public var version: NetworkAgentVersion?
  /// Optional field values payload.
  public var fields: [String: NetworkAgentFieldValue]?
  /// Optional stable wire-level error code.
  public var errorCode: NetworkAgentErrorCode?
  /// Optional legacy error message.
  public var message: String?

  /// Creates one network agent message.
  public init(
    kind: NetworkAgentMessageKind,
    version: NetworkAgentVersion? = nil,
    fields: [String: NetworkAgentFieldValue]? = nil,
    errorCode: NetworkAgentErrorCode? = nil,
    message: String? = nil
  ) {
    self.kind = kind
    self.version = version
    self.fields = fields
    self.errorCode = errorCode
    self.message = message
  }
}
