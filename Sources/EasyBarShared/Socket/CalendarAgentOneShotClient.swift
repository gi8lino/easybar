import Foundation

/// Sends one newline-delimited request to the calendar agent and reads one response.
public enum CalendarAgentOneShotClient {
  private static let encoder: JSONEncoder = {
    let encoder = LineSocketClientTransport<
      CalendarAgentRequest,
      CalendarAgentMessage
    >.makeDefaultEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  private static let decoder: JSONDecoder = {
    let decoder = LineSocketClientTransport<
      CalendarAgentRequest,
      CalendarAgentMessage
    >.makeDefaultDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  /// Sends one request and returns the first decoded response.
  public static func send(
    request: CalendarAgentRequest,
    socketPath: String
  ) throws -> CalendarAgentMessage {
    try LineSocketClientTransport<CalendarAgentRequest, CalendarAgentMessage>(
      socketPath: socketPath,
      encoder: encoder,
      decoder: decoder
    ).send(request: request)
  }
}
