import EasyBarConfigParsing
import EasyBarShared
import Foundation

extension Config.BuiltinBatteryColorMode: TOMLStringDecodable {}
extension Config.BuiltinBatteryDisplayMode: TOMLStringDecodable {}
extension Config.BuiltinWiFiContentMode: TOMLStringDecodable {}
extension Config.BuiltinWiFiContentSurface: TOMLStringDecodable {}

extension Config {
  /// Parses one configured minimum log level.
  func parseLogLevel(
    _ value: String,
    path: String
  ) throws -> ProcessLogLevel {
    if let parsed = ProcessLogLevel.normalized(value) {
      return parsed
    }

    let expected = ProcessLogLevel.allCases
      .map(\.rawValue)
      .sorted()
      .joined(separator: ", ")

    throw ConfigError.invalidValue(
      path: path,
      message: "expected one of \(expected)"
    )
  }

  /// Validates one configured built-in group reference.
  func validatedBuiltinGroupReference(
    _ value: String?,
    path: String,
    allowGroupReference: Bool
  ) throws -> String? {
    guard let value else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    guard allowGroupReference else {
      throw ConfigError.invalidValue(
        path: path,
        message: "built-in groups cannot be nested"
      )
    }

    guard builtinGroups.contains(where: { $0.id == trimmed }) else {
      let knownGroups = builtinGroups.map(\.id).sorted()

      if knownGroups.isEmpty {
        throw ConfigError.invalidValue(
          path: path,
          message: "unknown built-in group '\(trimmed)'"
        )
      }

      throw ConfigError.invalidValue(
        path: path,
        message:
          "unknown built-in group '\(trimmed)'; expected one of \(knownGroups.joined(separator: ", "))"
      )
    }

    return trimmed
  }

  /// Validates one configured spaces text weight.
  func validatedSpacesTextWeight(
    _ value: String,
    path: String
  ) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let normalized = trimmed.lowercased()

    let allowed = [
      "ultralight",
      "thin",
      "light",
      "regular",
      "medium",
      "semibold",
      "bold",
      "heavy",
      "black",
    ]

    guard allowed.contains(normalized) else {
      throw ConfigError.invalidValue(
        path: path,
        message: "expected one of \(allowed.joined(separator: ", "))"
      )
    }

    return trimmed
  }
}
