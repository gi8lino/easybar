import EasyBarShared
import Foundation
import TOMLKit

/// Describes one typed TOML field inside a calendar config table.
struct CalendarTOMLConfigField<Value> {
  let key: String
  let read: (CalendarBuiltinConfigParser, (any TOMLValueConvertible)?, String) throws -> Value?
}

extension CalendarTOMLConfigField where Value == String {
  /// Creates one optional string field descriptor.
  static func string(_ key: String) -> CalendarTOMLConfigField<String> {
    CalendarTOMLConfigField<String>(key: key) { parser, value, path in
      try parser.optionalString(value, path: path)
    }
  }
}

extension CalendarTOMLConfigField where Value == Bool {
  /// Creates one optional bool field descriptor.
  static func bool(_ key: String) -> CalendarTOMLConfigField<Bool> {
    CalendarTOMLConfigField<Bool>(key: key) { parser, value, path in
      try parser.optionalBool(value, path: path)
    }
  }
}

extension CalendarTOMLConfigField where Value == Int {
  /// Creates one optional integer field descriptor.
  static func int(_ key: String) -> CalendarTOMLConfigField<Int> {
    CalendarTOMLConfigField<Int>(key: key) { parser, value, path in
      try parser.optionalInt(value, path: path)
    }
  }
}

extension CalendarTOMLConfigField where Value == Double {
  /// Creates one optional number field descriptor.
  static func number(_ key: String) -> CalendarTOMLConfigField<Double> {
    CalendarTOMLConfigField<Double>(key: key) { parser, value, path in
      try parser.optionalNumber(value, path: path)
    }
  }
}

extension CalendarTOMLConfigField where Value == [String] {
  /// Creates one optional string-array field descriptor.
  static func stringArray(_ key: String) -> CalendarTOMLConfigField<[String]> {
    CalendarTOMLConfigField<[String]>(key: key) { parser, value, path in
      try parser.optionalStringArray(value, path: path)
    }
  }
}

extension CalendarBuiltinConfigParser {
  // MARK: - Enum parsing

  /// Parses one widget position.
  func parseWidgetPosition(_ value: String, path: String) throws -> WidgetPosition {
    guard let position = WidgetPosition(rawValue: value) else {
      throw invalid(path: path, expected: "one of left, center, right", actual: value)
    }

    return position
  }

  /// Parses the calendar popup mode.
  func parseCalendarPopupMode(_ value: String, path: String) throws -> CalendarPopupMode {
    guard let mode = CalendarPopupMode(rawValue: value) else {
      throw invalid(path: path, expected: "none, upcoming, or month", actual: value)
    }

    return mode
  }

  /// Parses the calendar anchor layout.
  func parseCalendarLayout(_ value: String, path: String) throws -> CalendarAnchorLayout {
    guard let layout = CalendarAnchorLayout(rawValue: value) else {
      throw invalid(path: path, expected: "item, stack, or inline", actual: value)
    }

    return layout
  }

  /// Parses the month popup layout.
  func parseMonthLayout(_ value: String, path: String) throws -> MonthCalendarPopupLayout {
    guard let layout = MonthCalendarPopupLayout(rawValue: value) else {
      throw invalid(
        path: path,
        expected:
          "calendar_appointments_horizontal, appointments_calendar_horizontal, calendar_appointments_vertical, or appointments_calendar_vertical",
        actual: value
      )
    }

    return layout
  }

  // MARK: - TOML helpers

  /// Parses one typed optional field from a table, falling back when the key is absent.
  func optionalField<Value>(
    _ field: CalendarTOMLConfigField<Value>,
    from table: TOMLTable,
    path: String,
    fallback: Value
  ) throws -> Value {
    try field.read(self, table[field.key], "\(path).\(field.key)") ?? fallback
  }

  /// Parses one typed optional field from a table, preserving an optional fallback when absent.
  func optionalField<Value>(
    _ field: CalendarTOMLConfigField<Value>,
    from table: TOMLTable,
    path: String,
    fallback: Value?
  ) throws -> Value? {
    try field.read(self, table[field.key], "\(path).\(field.key)") ?? fallback
  }

  /// Reads an optional TOML string.
  func optionalString(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
    guard let value else { return nil }

    guard let string = value.string else {
      throw invalid(path: path, expected: "string", actual: String(describing: value))
    }

    return string
  }

  /// Reads an optional TOML bool.
  func optionalBool(_ value: (any TOMLValueConvertible)?, path: String) throws -> Bool? {
    guard let value else { return nil }

    guard let bool = value.bool else {
      throw invalid(path: path, expected: "bool", actual: String(describing: value))
    }

    return bool
  }

  /// Reads an optional TOML number.
  func optionalNumber(_ value: (any TOMLValueConvertible)?, path: String) throws -> Double? {
    guard let value else { return nil }

    if let double = value.double {
      return double
    }

    if let int = value.int {
      return Double(int)
    }

    throw invalid(path: path, expected: "number", actual: String(describing: value))
  }

  /// Reads an optional TOML integer.
  func optionalInt(_ value: (any TOMLValueConvertible)?, path: String) throws -> Int? {
    guard let value else { return nil }

    guard let int = value.int else {
      throw invalid(path: path, expected: "integer", actual: String(describing: value))
    }

    return int
  }

  /// Reads an optional TOML string array.
  func optionalStringArray(
    _ value: (any TOMLValueConvertible)?,
    path: String
  ) throws -> [String]? {
    guard let value else { return nil }

    guard let array = value.array else {
      throw invalid(path: path, expected: "array of strings", actual: String(describing: value))
    }

    return try array.enumerated().map { index, item in
      guard let string = item.string else {
        throw invalid(
          path: "\(path)[\(index)]",
          expected: "string",
          actual: String(describing: item)
        )
      }

      return string
    }
  }

  /// Reads a string map from one TOML table.
  func optionalStringMap(_ table: TOMLTable) throws -> [String: String]? {
    guard !table.keys.isEmpty else { return nil }

    var result: [String: String] = [:]

    for key in table.keys.sorted() {
      guard let value = table[key]?.string else {
        throw invalid(
          path: "\(rootPath).composer.\(key)",
          expected: "string",
          actual: String(describing: table[key] as Any)
        )
      }

      result[key] = value
    }

    return result
  }

  /// Builds one parser error.
  func invalid(path: String, expected: String, actual: String) -> CalendarConfigError {
    CalendarConfigError(configPath: path, expected: expected, actual: actual)
  }
}
