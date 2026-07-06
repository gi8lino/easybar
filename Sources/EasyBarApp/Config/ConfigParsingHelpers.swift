import EasyBarShared
import Foundation
import TOMLKit

/// Describes one typed TOML field inside a config table.
struct TOMLConfigField<Value> {
  let key: String
  let read: (Config, (any TOMLValueConvertible)?, String) throws -> Value?
}

extension TOMLConfigField where Value == String {
  /// Creates one optional string field descriptor.
  static func string(_ key: String) -> TOMLConfigField<String> {
    TOMLConfigField<String>(key: key) { config, value, path in
      try config.optionalString(value, path: path)
    }
  }

  /// Creates one optional path field descriptor that expands `~`.
  static func expandedPath(_ key: String) -> TOMLConfigField<String> {
    TOMLConfigField<String>(key: key) { config, value, path in
      try config.optionalExpandedPath(value, path: path)
    }
  }
}

extension TOMLConfigField where Value == Bool {
  /// Creates one optional bool field descriptor.
  static func bool(_ key: String) -> TOMLConfigField<Bool> {
    TOMLConfigField<Bool>(key: key) { config, value, path in
      try config.optionalBool(value, path: path)
    }
  }
}

extension TOMLConfigField where Value == Int {
  /// Creates one optional integer field descriptor.
  static func int(_ key: String) -> TOMLConfigField<Int> {
    TOMLConfigField<Int>(key: key) { config, value, path in
      try config.optionalInt(value, path: path)
    }
  }
}

extension TOMLConfigField where Value == Double {
  /// Creates one optional number field descriptor.
  static func number(_ key: String) -> TOMLConfigField<Double> {
    TOMLConfigField<Double>(key: key) { config, value, path in
      try config.optionalNumber(value, path: path)
    }
  }
}

extension TOMLConfigField where Value == [String] {
  /// Creates one optional string-array field descriptor.
  static func stringArray(_ key: String) -> TOMLConfigField<[String]> {
    TOMLConfigField<[String]>(key: key) { config, value, path in
      try config.optionalStringArray(value, path: path)
    }
  }
}

extension TOMLConfigField where Value == [String: String] {
  /// Creates one optional string-table field descriptor.
  static func stringTable(_ key: String) -> TOMLConfigField<[String: String]> {
    TOMLConfigField<[String: String]>(key: key) { config, value, path in
      try config.optionalStringTable(value, path: path)
    }
  }
}

extension Config {

  /// Parses one typed optional field from a table, falling back when the key is absent.
  func optionalField<Value>(
    _ field: TOMLConfigField<Value>,
    from table: TOMLTable,
    path: String,
    fallback: Value
  ) throws -> Value {
    try field.read(self, table[field.key], "\(path).\(field.key)") ?? fallback
  }

  /// Parses one typed optional field from a table, preserving an optional fallback when absent.
  func optionalField<Value>(
    _ field: TOMLConfigField<Value>,
    from table: TOMLTable,
    path: String,
    fallback: Value?
  ) throws -> Value? {
    try field.read(self, table[field.key], "\(path).\(field.key)") ?? fallback
  }

  /// Parses one placement block.
  func parseBuiltinPlacement(
    from table: TOMLTable,
    path: String,
    fallback: BuiltinWidgetPlacement,
    allowGroupReference: Bool = true
  ) throws -> BuiltinWidgetPlacement {
    let rawGroup =
      try optionalField(.string("group"), from: table, path: path, fallback: fallback.group)

    return BuiltinWidgetPlacement(
      enabled: try optionalField(.bool("enabled"), from: table, path: path, fallback: fallback.enabled),
      position: try parsePosition(
        try optionalField(.string("position"), from: table, path: path, fallback: fallback.position.rawValue),
        path: "\(path).position"
      ),
      order: try optionalField(.int("order"), from: table, path: path, fallback: fallback.order),
      group: try validatedBuiltinGroupReference(
        rawGroup,
        path: "\(path).group",
        allowGroupReference: allowGroupReference
      )
    )
  }

  /// Parses one style block.
  func parseBuiltinStyle(
    from table: TOMLTable,
    path: String,
    fallback: BuiltinWidgetStyle
  ) throws -> BuiltinWidgetStyle {
    BuiltinWidgetStyle(
      icon: try optionalField(.string("icon"), from: table, path: path, fallback: fallback.icon),
      textColorHex: try optionalField(
        .string("text_color"),
        from: table,
        path: path,
        fallback: fallback.textColorHex
      ),
      backgroundColorHex: try optionalField(
        .string("background_color"),
        from: table,
        path: path,
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try optionalField(
        .string("border_color"),
        from: table,
        path: path,
        fallback: fallback.borderColorHex
      ),
      borderWidth: try optionalField(
        .number("border_width"),
        from: table,
        path: path,
        fallback: fallback.borderWidth
      ),
      cornerRadius: try optionalField(
        .number("corner_radius"),
        from: table,
        path: path,
        fallback: fallback.cornerRadius
      ),
      marginX: try optionalField(.number("margin_x"), from: table, path: path, fallback: fallback.marginX),
      marginY: try optionalField(.number("margin_y"), from: table, path: path, fallback: fallback.marginY),
      paddingX: try optionalField(
        .number("padding_x"),
        from: table,
        path: path,
        fallback: fallback.paddingX
      ),
      paddingY: try optionalField(
        .number("padding_y"),
        from: table,
        path: path,
        fallback: fallback.paddingY
      ),
      spacing: try optionalField(.number("spacing"), from: table, path: path, fallback: fallback.spacing),
      opacity: try optionalField(.number("opacity"), from: table, path: path, fallback: fallback.opacity)
    )
  }

  /// Parses one tooltip style block shared by simple built-ins.
  func parseBuiltinPopupStyle(
    from table: TOMLTable,
    path: String,
    fallback: BuiltinPopupStyle
  ) throws -> BuiltinPopupStyle {
    BuiltinPopupStyle(
      textColorHex: try optionalField(
        .string("text_color"),
        from: table,
        path: path,
        fallback: fallback.textColorHex
      ),
      backgroundColorHex: try optionalField(
        .string("background_color"),
        from: table,
        path: path,
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try optionalField(
        .string("border_color"),
        from: table,
        path: path,
        fallback: fallback.borderColorHex
      ),
      borderWidth: try optionalField(
        .number("border_width"),
        from: table,
        path: path,
        fallback: fallback.borderWidth
      ),
      cornerRadius: try optionalField(
        .number("corner_radius"),
        from: table,
        path: path,
        fallback: fallback.cornerRadius
      ),
      paddingX: try optionalField(
        .number("padding_x"),
        from: table,
        path: path,
        fallback: fallback.paddingX
      ),
      paddingY: try optionalField(
        .number("padding_y"),
        from: table,
        path: path,
        fallback: fallback.paddingY
      ),
      marginX: try optionalField(.number("margin_x"), from: table, path: path, fallback: fallback.marginX),
      marginY: try optionalField(.number("margin_y"), from: table, path: path, fallback: fallback.marginY)
    )
  }

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

  /// Parses one battery color mode.
  func parseBatteryColorMode(
    _ value: String,
    path: String
  ) throws -> BuiltinBatteryColorMode {
    try parseStringEnum(
      value,
      as: BuiltinBatteryColorMode.self,
      path: path
    )
  }

  /// Parses one battery display mode.
  func parseBatteryDisplayMode(
    _ value: String,
    path: String
  ) throws -> BuiltinBatteryDisplayMode {
    try parseStringEnum(
      value,
      as: BuiltinBatteryDisplayMode.self,
      path: path
    )
  }

  /// Parses one Wi-Fi content mode.
  func parseWiFiContentMode(
    _ value: String,
    path: String
  ) throws -> BuiltinWiFiContentMode {
    try parseStringEnum(
      value,
      as: BuiltinWiFiContentMode.self,
      path: path
    )
  }

  /// Parses one Wi-Fi content surface.
  func parseWiFiContentSurface(
    _ value: String,
    path: String
  ) throws -> BuiltinWiFiContentSurface {
    try parseStringEnum(
      value,
      as: BuiltinWiFiContentSurface.self,
      path: path
    )
  }

  /// Parses one calendar popup mode.
  func parseCalendarPopupMode(
    _ value: String,
    path: String
  ) throws -> CalendarPopupMode {
    try parseStringEnum(
      value,
      as: CalendarPopupMode.self,
      path: path
    )
  }

  /// Parses one month-calendar popup layout mode.
  func parseMonthCalendarPopupLayout(
    _ value: String,
    path: String
  ) throws -> MonthCalendarPopupLayout {
    try parseStringEnum(
      value,
      as: MonthCalendarPopupLayout.self,
      path: path
    )
  }

  /// Parses one widget position.
  func parsePosition(
    _ value: String,
    path: String
  ) throws -> WidgetPosition {
    let normalized = normalizedEnumValue(value)

    guard let parsed = WidgetPosition(rawValue: normalized) else {
      throw ConfigError.invalidValue(
        path: path,
        message: "expected one of left, center, right"
      )
    }

    return parsed
  }

  /// Parses one calendar anchor layout.
  func parseCalendarLayout(
    _ value: String,
    path: String
  ) throws -> CalendarAnchorLayout {
    let normalized = normalizedEnumValue(value)

    guard let parsed = CalendarAnchorLayout(rawValue: normalized) else {
      throw ConfigError.invalidValue(
        path: path,
        message: "unsupported value '\(value.trimmingCharacters(in: .whitespacesAndNewlines))'"
      )
    }

    return parsed
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

  /// Parses one generic string-backed enum case-insensitively.
  private func parseStringEnum<T>(
    _ value: String,
    as type: T.Type,
    path: String
  ) throws -> T where T: RawRepresentable, T: CaseIterable, T.RawValue == String {
    let normalized = normalizedEnumValue(value)

    guard let parsed = T(rawValue: normalized) else {
      let expected = T.allCases.map(\.rawValue).sorted().joined(separator: ", ")
      throw ConfigError.invalidValue(
        path: path,
        message: "expected one of \(expected)"
      )
    }

    return parsed
  }

  /// Normalizes one string enum token for forgiving parsing.
  private func normalizedEnumValue(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
  }

  /// Returns a required TOML string or throws a typed config error.
  func requiredString(_ value: any TOMLValueConvertible, path: String) throws -> String {
    if let string = value.string {
      return string
    }

    throw ConfigError.invalidType(
      path: path,
      expected: "string",
      actual: describe(value)
    )
  }

  /// Returns a required TOML bool or throws a typed config error.
  func requiredBool(_ value: any TOMLValueConvertible, path: String) throws -> Bool {
    if let bool = value.bool {
      return bool
    }

    throw ConfigError.invalidType(
      path: path,
      expected: "bool",
      actual: describe(value)
    )
  }

  /// Returns a required TOML integer or throws a typed config error.
  func requiredInt(_ value: any TOMLValueConvertible, path: String) throws -> Int {
    if let int = value.int {
      return int
    }

    throw ConfigError.invalidType(
      path: path,
      expected: "integer",
      actual: describe(value)
    )
  }

  /// Returns a required finite TOML number or throws a typed config error.
  func requiredNumber(_ value: any TOMLValueConvertible, path: String) throws -> Double {
    let number: Double

    if let double = value.double {
      number = double
    } else if let int = value.int {
      number = Double(int)
    } else {
      throw ConfigError.invalidType(
        path: path,
        expected: "number",
        actual: describe(value)
      )
    }

    guard number.isFinite else {
      throw ConfigError.invalidValue(
        path: path,
        message: "expected a finite number"
      )
    }

    return number
  }

  /// Returns a required TOML string array or throws a typed config error.
  func requiredStringArray(_ value: any TOMLValueConvertible, path: String) throws -> [String] {
    guard let array = value.array else {
      throw ConfigError.invalidType(
        path: path,
        expected: "array",
        actual: describe(value)
      )
    }

    return try array.enumerated().map { index, entry in
      try requiredString(entry, path: "\(path)[\(index)]")
    }
  }

  /// Returns a required TOML string table or throws a typed config error.
  func requiredStringTable(
    _ value: any TOMLValueConvertible,
    path: String
  ) throws -> [String: String] {
    guard let table = value.table else {
      throw ConfigError.invalidType(
        path: path,
        expected: "table",
        actual: describe(value)
      )
    }

    return try table.reduce(into: [String: String]()) { result, entry in
      let (key, value) = entry
      result[key] = try requiredString(value, path: "\(path).\(key)")
    }
  }

  /// Returns a stable type description for one TOML value.
  func describe(_ value: any TOMLValueConvertible) -> String {
    if let string = value.string {
      return "string(\(string.debugDescription))"
    }

    if let int = value.int {
      return "integer(\(int))"
    }

    if let double = value.double {
      return "number(\(double))"
    }

    if let bool = value.bool {
      return "bool(\(bool))"
    }

    if value.array != nil {
      return "array"
    }

    if value.table != nil {
      return "table"
    }

    return "unknown"
  }

  /// Returns an optional TOML string when present.
  func optionalString(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
    guard let value else { return nil }
    return try requiredString(value, path: path)
  }

  /// Returns an optional TOML bool when present.
  func optionalBool(_ value: (any TOMLValueConvertible)?, path: String) throws -> Bool? {
    guard let value else { return nil }
    return try requiredBool(value, path: path)
  }

  /// Returns an optional TOML integer when present.
  func optionalInt(_ value: (any TOMLValueConvertible)?, path: String) throws -> Int? {
    guard let value else { return nil }
    return try requiredInt(value, path: path)
  }

  /// Returns an optional TOML number when present.
  func optionalNumber(_ value: (any TOMLValueConvertible)?, path: String) throws -> Double? {
    guard let value else { return nil }
    return try requiredNumber(value, path: path)
  }

  /// Returns an optional TOML string array when present.
  func optionalStringArray(_ value: (any TOMLValueConvertible)?, path: String) throws -> [String]? {
    guard let value else { return nil }
    return try requiredStringArray(value, path: path)
  }

  /// Returns an optional TOML string table when present.
  func optionalStringTable(
    _ value: (any TOMLValueConvertible)?,
    path: String
  ) throws -> [String: String]? {
    guard let value else { return nil }
    return try requiredStringTable(value, path: path)
  }

  /// Parses one optional path string and expands `~` when present.
  func optionalExpandedPath(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
    return expandedPath(try optionalString(value, path: path))
  }
}
