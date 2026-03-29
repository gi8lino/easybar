import Foundation

/// Commands supported by the network agent socket.
public enum NetworkAgentCommand: String, Codable {
  case ping
  case fetch
  case subscribe
}

/// Field keys supported by the network agent.
public enum NetworkAgentField: String, Codable, CaseIterable {
  case accessGranted = "network.access_granted"
  case permissionState = "network.permission_state"
  case generatedAt = "network.generated_at"
  case ssid = "wifi.ssid"
  case interfaceName = "wifi.interface"
  case primaryInterfaceIsTunnel = "network.primary_interface_is_tunnel"
  case rssi = "wifi.rssi"
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
}

/// Full network snapshot returned by the agent.
public struct NetworkAgentSnapshot: Codable, Equatable {
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
  public init?(fields: [String: String]) {
    guard
      let accessGranted = fields[NetworkAgentField.accessGranted.rawValue].flatMap(Bool.init),
      let permissionState = fields[NetworkAgentField.permissionState.rawValue],
      let generatedAtRaw = fields[NetworkAgentField.generatedAt.rawValue],
      let generatedAt = ISO8601DateFormatter().date(from: generatedAtRaw),
      let primaryInterfaceIsTunnel = fields[NetworkAgentField.primaryInterfaceIsTunnel.rawValue]
        .flatMap(Bool.init)
    else {
      return nil
    }

    self.init(
      accessGranted: accessGranted,
      permissionState: permissionState,
      generatedAt: generatedAt,
      ssid: fields[NetworkAgentField.ssid.rawValue],
      interfaceName: fields[NetworkAgentField.interfaceName.rawValue],
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      rssi: fields[NetworkAgentField.rssi.rawValue].flatMap(Int.init)
    )
  }
}

/// Message kinds sent by the network agent.
public enum NetworkAgentMessageKind: String, Codable {
  case pong
  case subscribed
  case fields
  case error
}

/// One message sent over the network agent socket.
public struct NetworkAgentMessage: Codable {
  /// Message kind discriminator.
  public var kind: NetworkAgentMessageKind
  /// Optional field values payload.
  public var fields: [String: String]?
  /// Optional error message.
  public var message: String?

  /// Creates one network agent message.
  public init(
    kind: NetworkAgentMessageKind,
    fields: [String: String]? = nil,
    message: String? = nil
  ) {
    self.kind = kind
    self.fields = fields
    self.message = message
  }
}
