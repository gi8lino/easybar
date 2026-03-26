import Foundation

enum ConfigError: Error, LocalizedError {
  case invalidType(path: String, expected: String, actual: String)
  case invalidValue(path: String, message: String)

  var errorDescription: String? {
    switch self {
    case .invalidType(let path, let expected, let actual):
      return "\(path): expected \(expected), got \(actual)"
    case .invalidValue(let path, let message):
      return "\(path): \(message)"
    }
  }
}
