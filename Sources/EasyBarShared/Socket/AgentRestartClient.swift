import Foundation

/// Sends acknowledged restart requests to the supervised EasyBar helper agents.
public enum AgentRestartClient {
  /// Asks the calendar agent to exit so its service supervisor can relaunch it.
  public static func restartCalendarAgent(socketPath: String) throws {
    let response = try CalendarAgentOneShotClient.send(
      request: CalendarAgentRequest(command: .restart),
      socketPath: socketPath
    )
    guard response.kind == .restarting else {
      throw AgentRestartError.unexpectedResponse
    }
  }

  /// Asks the network agent to exit so its service supervisor can relaunch it.
  public static func restartNetworkAgent(socketPath: String) throws {
    let transport = LineSocketClientTransport<NetworkAgentRequest, NetworkAgentMessage>(
      socketPath: socketPath
    )
    let response = try transport.send(request: NetworkAgentRequest(command: .restart))
    guard response.kind == .restarting else {
      throw AgentRestartError.unexpectedResponse
    }
  }
}

public enum AgentRestartError: Error {
  case unexpectedResponse
}
