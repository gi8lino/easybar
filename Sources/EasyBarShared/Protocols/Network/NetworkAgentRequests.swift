import Foundation

/// One request sent to the network agent.
public struct NetworkAgentRequest: Codable, Sendable {
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
