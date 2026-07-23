import Foundation

/// Queries the versions of running EasyBar helper agents through their sockets.
public enum AgentVersionClient {
  /// Returns the version reported by the running calendar agent.
  public static func calendarAgentVersion(socketPath: String) throws -> CalendarAgentVersion {
    let response: CalendarAgentMessage
    do {
      response = try CalendarAgentOneShotClient.send(
        request: CalendarAgentRequest(command: .version),
        socketPath: socketPath
      )
    } catch {
      throw AgentVersionClientError.transport(error.localizedDescription)
    }

    guard response.kind == .version, let version = response.version else {
      throw AgentVersionClientError.unexpectedResponse
    }
    return version
  }

  /// Returns the version reported by the running network agent.
  public static func networkAgentVersion(socketPath: String) throws -> NetworkAgentVersion {
    let transport = LineSocketClientTransport<NetworkAgentRequest, NetworkAgentMessage>(
      socketPath: socketPath
    )
    let response: NetworkAgentMessage
    do {
      response = try transport.send(request: NetworkAgentRequest(command: .version))
    } catch let error as LineSocketClientTransportError {
      throw AgentVersionClientError.transport(error.description)
    } catch {
      throw AgentVersionClientError.transport(error.localizedDescription)
    }

    guard response.kind == .version, let version = response.version else {
      throw AgentVersionClientError.unexpectedResponse
    }
    return version
  }
}

/// Errors returned while querying one helper-agent version.
public enum AgentVersionClientError: LocalizedError {
  case unexpectedResponse
  case transport(String)

  public var errorDescription: String? {
    switch self {
    case .unexpectedResponse:
      return "agent returned an unexpected version response"
    case .transport(let message):
      return "agent socket request failed: \(message)"
    }
  }
}
