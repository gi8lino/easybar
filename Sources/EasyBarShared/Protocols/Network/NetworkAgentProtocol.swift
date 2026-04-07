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
    Self(command: .fetch, fields: fields)
  }

  /// Builds one subscribe request.
  public static func subscribe(_ fields: [NetworkAgentField]) -> Self {
    Self(command: .subscribe, fields: fields)
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
    .interfaceName,
    .primaryInterfaceIsTunnel,
    .rssi,
  ]

  /// Whether location/Wi-Fi access is currently granted.
  public var accessGranted: Bool
  /// Current permission state string.
  public var permissionState: String
  /// Snapshot generation time.
  public var generatedAt: Date
  /// Active Wi-Fi SSID when available.
  public var ssid: String?
  /// Active Wi-Fi interface name when available.
  public var interfaceName: String?
  /// Whether the current primary interface is a tunnel.
  public var primaryInterfaceIsTunnel: Bool
  /// Raw or smoothed RSSI value when available.
  public var rssi: Int?

  /// Creates one network snapshot payload.
  public init(
    accessGranted: Bool,
    permissionState: String,
    generatedAt: Date,
    ssid: String?,
    interfaceName: String?,
    primaryInterfaceIsTunnel: Bool,
    rssi: Int?
  ) {
    self.accessGranted = accessGranted
    self.permissionState = permissionState
    self.generatedAt = generatedAt
    self.ssid = ssid
    self.interfaceName = interfaceName
    self.primaryInterfaceIsTunnel = primaryInterfaceIsTunnel
    self.rssi = rssi
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
      interfaceName: fields[NetworkAgentField.interfaceName.rawValue]?.stringValue,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      rssi: fields[NetworkAgentField.rssi.rawValue]?.intValue
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
