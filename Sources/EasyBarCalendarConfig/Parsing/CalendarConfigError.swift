import Foundation

/// Validation errors raised while parsing shared calendar config.
public struct CalendarConfigError: Error, LocalizedError, Sendable {
  /// Config path associated with the validation failure.
  public let configPath: String
  /// Expected TOML type or allowed value description.
  public let expected: String
  /// Actual TOML value or invalid value description.
  public let actual: String

  /// Creates one calendar config validation error.
  public init(
    configPath: String,
    expected: String,
    actual: String
  ) {
    self.configPath = configPath
    self.expected = expected
    self.actual = actual
  }

  /// Returns the config item associated with the failure.
  public var problemItem: String? {
    return configPath
  }

  /// Returns the invalid TOML value or value description.
  public var problemValue: String? {
    return actual
  }

  /// Returns the human-readable validation detail.
  public var detail: String {
    return "expected \(expected), got \(actual)"
  }

  public var errorDescription: String? {
    return "invalid value at \(configPath): \(detail)"
  }
}
