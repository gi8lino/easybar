import Foundation

/// Minimum severity accepted by the shared process logger.
public enum ProcessLogLevel: String, Codable, CaseIterable, Sendable {
  case trace
  case debug
  case info
  case warn
  case error

  /// Returns whether a message at the given level should be emitted.
  public func allows(_ level: ProcessLogLevel) -> Bool {
    level.rank >= rank
  }

  /// Returns the normalized level for one free-form string.
  public static func normalized(_ value: String?) -> ProcessLogLevel? {
    guard let value else { return nil }

    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "trace":
      return .trace
    case "debug":
      return .debug
    case "info":
      return .info
    case "warn", "warning":
      return .warn
    case "error":
      return .error
    default:
      return nil
    }
  }

  /// Stable integer ordering used for minimum-level comparisons.
  private var rank: Int {
    switch self {
    case .trace:
      return 0
    case .debug:
      return 1
    case .info:
      return 2
    case .warn:
      return 3
    case .error:
      return 4
    }
  }
}
