import Foundation

/// One version payload returned by the calendar agent.
public struct CalendarAgentVersion: Codable, Equatable, Sendable {
  /// The application version embedded in the calendar-agent build.
  public var appVersion: String
  /// Shared EasyBar IPC protocol version.
  public var protocolVersion: String

  /// Creates one calendar-agent version payload.
  public init(
    appVersion: String,
    protocolVersion: String
  ) {
    self.appVersion = appVersion
    self.protocolVersion = protocolVersion
  }
}

public enum CalendarAgentMessageKind: String, Codable, Sendable {
  case pong
  case version
  case subscribed
  case restarting
  case snapshot
  case created
  case updated
  case deleted
  case error
}

/// One message sent over the calendar agent socket.
public struct CalendarAgentMessage: Codable, Sendable {
  /// Message kind discriminator.
  public var kind: CalendarAgentMessageKind
  /// Optional version payload.
  public var version: CalendarAgentVersion?
  /// Optional snapshot payload.
  public var snapshot: CalendarAgentSnapshot?
  /// Optional structured error code.
  public var errorCode: CalendarAgentErrorCode?
  /// Optional error message.
  public var message: String?

  /// Creates one calendar agent message.
  public init(
    kind: CalendarAgentMessageKind,
    version: CalendarAgentVersion? = nil,
    snapshot: CalendarAgentSnapshot? = nil,
    errorCode: CalendarAgentErrorCode? = nil,
    message: String? = nil
  ) {
    self.kind = kind
    self.version = version
    self.snapshot = snapshot
    self.errorCode = errorCode
    self.message = message
  }
}
