import Foundation

/// Shared event-name catalog and Lua parity checks.
enum EventCatalog {
  static let forcedEventName = "forced"

  static let luaTokenEventNames: Set<String> = Set(AppEvent.luaTokenEvents.map(\.rawValue))
    .union(Set(WidgetEvent.allCases.map(\.rawValue)))
    .union([forcedEventName])

  static let luaDriverEventNames: Set<String> = Set(AppEvent.luaDriverEvents.map(\.rawValue))
    .union([forcedEventName])

  /// Verifies that the Lua token file matches the Swift event catalog.
  static func validateLuaDefinitions() {
    let warnings = currentLuaDefinitionWarnings()

    guard !warnings.isEmpty else { return }

    for warning in warnings {
      easybarLog.warn(warning)
    }
  }

  /// Returns human-readable mismatch warnings for the Lua token definitions.
  static func currentLuaDefinitionWarnings() -> [String] {
    guard let source = loadLuaEventTokenSource() else {
      return [
        "unable to validate Lua event token parity because Lua/easybar/event_tokens.lua could not be loaded"
      ]
    }

    let luaTokenNames = parseMatches(
      pattern: #"make_event_token\("([^"]+)"\)"#,
      in: source
    )

    let luaDriverNames = parseMatches(
      pattern: #"(?m)^\s*([a-z_]+)\s*=\s*true\s*,?$"#,
      in: source
    )

    var warnings: [String] = []
    appendMismatchWarnings(
      label: "lua event tokens",
      expected: luaTokenEventNames,
      actual: luaTokenNames,
      warnings: &warnings
    )
    appendMismatchWarnings(
      label: "lua driver events",
      expected: luaDriverEventNames,
      actual: luaDriverNames,
      warnings: &warnings
    )
    return warnings
  }

  /// Loads the bundled Lua event token source.
  private static func loadLuaEventTokenSource() -> String? {
    guard
      let url = Bundle.module.url(
        forResource: "event_tokens",
        withExtension: "lua",
        subdirectory: "Lua/easybar"
      ),
      let source = try? String(contentsOf: url)
    else {
      return nil
    }

    return source
  }

  /// Returns every first capture group match for the given regex pattern.
  private static func parseMatches(pattern: String, in source: String) -> Set<String> {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let range = NSRange(source.startIndex..., in: source)
    let matches = regex.matches(in: source, range: range)

    return Set(
      matches.compactMap { match in
        guard match.numberOfRanges > 1,
          let range = Range(match.range(at: 1), in: source)
        else {
          return nil
        }

        return String(source[range])
      })
  }

  /// Appends missing and unexpected event-name warnings for one Lua definition set.
  private static func appendMismatchWarnings(
    label: String,
    expected: Set<String>,
    actual: Set<String>,
    warnings: inout [String]
  ) {
    let missing = expected.subtracting(actual).sorted()
    let unexpected = actual.subtracting(expected).sorted()

    if !missing.isEmpty {
      warnings.append("\(label) missing Swift-defined names: \(missing.joined(separator: ", "))")
    }

    if !unexpected.isEmpty {
      warnings.append(
        "\(label) contain names missing from Swift: \(unexpected.joined(separator: ", "))")
    }
  }
}
