import Foundation

/// Validation errors raised while parsing reusable calendar config.
public enum CalendarConfigError: Error, LocalizedError {
  /// A config value had the wrong TOML type.
  case invalidType(path: String, expected: String, actual: String)
  /// A config value had an unsupported value.
  case invalidValue(path: String, message: String)

  /// Returns the config path associated with the validation failure.
  public var configPath: String {
    switch self {
    case .invalidType(let path, _, _):
      return path
    case .invalidValue(let path, _):
      return path
    }
  }

  /// Returns the item/key that caused the failure when available.
  public var problemItem: String? {
    return configPath
  }

  /// Returns the problematic TOML value or value description when available.
  public var problemValue: String? {
    switch self {
    case .invalidType(_, _, let actual):
      return actual
    case .invalidValue:
      return nil
    }
  }

  /// Returns the human-readable failure detail without the config path prefix.
  public var detail: String {
    switch self {
    case .invalidType(_, let expected, let actual):
      return "expected \(expected), got \(actual)"
    case .invalidValue(_, let message):
      return message
    }
  }

  public var errorDescription: String? {
    return "\(configPath): \(detail)"
  }
}
