import Foundation

/// Errors raised while loading the shared runtime subset of EasyBar config.
public enum SharedRuntimeConfigError: Error, LocalizedError, Equatable {
  /// The config file could not be read.
  case readFailure(path: String, message: String)
  /// The config file is not valid TOML.
  case parseFailure(path: String, message: String)
  /// A config value had the wrong TOML type.
  case invalidType(path: String, expected: String, actual: String)
  /// A config value had an unsupported value.
  case invalidValue(path: String, message: String)

  public var errorDescription: String? {
    switch self {
    case .readFailure(let path, let message):
      return "failed to read shared runtime config at \(path): \(message)"

    case .parseFailure(let path, let message):
      return "failed to parse shared runtime config at \(path): \(message)"

    case .invalidType(let path, let expected, let actual):
      return "invalid shared runtime config type at \(path): expected \(expected), got \(actual)"

    case .invalidValue(let path, let message):
      return "invalid shared runtime config value at \(path): \(message)"
    }
  }
}
