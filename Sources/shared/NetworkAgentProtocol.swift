import Foundation

/// Commands supported by the network agent socket.
public enum NetworkAgentCommand: String, Codable {
  case ping
  case fetch
  case subscribe
}

/// One request sent to the network agent.
public struct NetworkAgentRequest: Codable {
  /// Command to execute on the agent.
  public var command: NetworkAgentCommand

  /// Creates one network agent request.
  public init(command: NetworkAgentCommand) {
    self.command = command
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
}

/// Message kinds sent by the network agent.
public enum NetworkAgentMessageKind: String, Codable {
  case pong
  case subscribed
  case snapshot
  case error
}

/// One message sent over the network agent socket.
public struct NetworkAgentMessage: Codable {
  /// Message kind discriminator.
  public var kind: NetworkAgentMessageKind
  /// Optional snapshot payload.
  public var snapshot: NetworkAgentSnapshot?
  /// Optional error message.
  public var message: String?

  /// Creates one network agent message.
  public init(
    kind: NetworkAgentMessageKind,
    snapshot: NetworkAgentSnapshot? = nil,
    message: String? = nil
  ) {
    self.kind = kind
    self.snapshot = snapshot
    self.message = message
  }
}
