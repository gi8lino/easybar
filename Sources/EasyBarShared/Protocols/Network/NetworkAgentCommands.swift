import Foundation

public enum NetworkAgentCommand: String, Codable {
  case ping
  case version
  case fetch
  case subscribe
}

/// Field keys supported by the network agent.

public enum NetworkAgentErrorCode: String, Codable, Equatable {
  case permissionDenied = "permission_denied"
  case missingFields = "missing_fields"
  case providerUnavailable = "provider_unavailable"
  case unknown = "unknown"
}

/// Describes one shared network-agent field.
