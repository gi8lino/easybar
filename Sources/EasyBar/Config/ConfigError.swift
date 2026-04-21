import Foundation

enum ConfigError: Error, LocalizedError {
  case invalidType(path: String, expected: String, actual: String)
  case invalidValue(path: String, message: String)

  /// Returns the config path associated with the validation failure.
  var configPath: String {
    switch self {
    case .invalidType(let path, _, _):
      return path
    case .invalidValue(let path, _):
      return path
    }
  }

  /// Returns the human-readable failure detail without the config path prefix.
  var detail: String {
    switch self {
    case .invalidType(_, let expected, let actual):
      return "expected \(expected), got \(actual)"
    case .invalidValue(_, let message):
      return message
    }
  }

  var errorDescription: String? {
    "\(configPath): \(detail)"
  }
}
