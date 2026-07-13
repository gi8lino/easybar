import Foundation

public enum NetworkAgentMessageKind: String, Codable, Sendable {
  case pong
  case version
  case subscribed
  case fields
  case error
}

/// One message sent over the network agent socket.
public struct NetworkAgentMessage: Codable, Sendable {
  /// Message kind discriminator.
  public var kind: NetworkAgentMessageKind
  /// Optional version payload.
  public var version: NetworkAgentVersion?
  /// Optional field values payload.
  public var fields: [String: NetworkAgentFieldValue]?
  /// Optional stable wire-level error code.
  public var errorCode: NetworkAgentErrorCode?

  /// Creates one network agent message.
  public init(
    kind: NetworkAgentMessageKind,
    version: NetworkAgentVersion? = nil,
    fields: [String: NetworkAgentFieldValue]? = nil,
    errorCode: NetworkAgentErrorCode? = nil
  ) {
    self.kind = kind
    self.version = version
    self.fields = fields
    self.errorCode = errorCode
  }
}
