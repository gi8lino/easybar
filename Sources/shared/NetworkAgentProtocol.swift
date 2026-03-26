import Foundation

public enum NetworkAgentCommand: String, Codable {
  case ping
  case fetch
  case subscribe
}

public struct NetworkAgentRequest: Codable {
  public var command: NetworkAgentCommand

  public init(command: NetworkAgentCommand) {
    self.command = command
  }
}

public struct NetworkAgentSnapshot: Codable, Equatable {
  public var accessGranted: Bool
  public var permissionState: String
  public var generatedAt: Date
  public var ssid: String?
  public var interfaceName: String?
  public var primaryInterfaceIsTunnel: Bool
  public var signalBars: Int
  public var rssi: Int?

  public init(
    accessGranted: Bool,
    permissionState: String,
    generatedAt: Date,
    ssid: String?,
    interfaceName: String?,
    primaryInterfaceIsTunnel: Bool,
    signalBars: Int,
    rssi: Int?
  ) {
    self.accessGranted = accessGranted
    self.permissionState = permissionState
    self.generatedAt = generatedAt
    self.ssid = ssid
    self.interfaceName = interfaceName
    self.primaryInterfaceIsTunnel = primaryInterfaceIsTunnel
    self.signalBars = signalBars
    self.rssi = rssi
  }
}

public enum NetworkAgentMessageKind: String, Codable {
  case pong
  case subscribed
  case snapshot
  case error
}

public struct NetworkAgentMessage: Codable {
  public var kind: NetworkAgentMessageKind
  public var snapshot: NetworkAgentSnapshot?
  public var message: String?

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
