import EasyBarShared
import Foundation
import TOMLKit

extension Config {

  /// Parses one placement block.
  func parseBuiltinPlacement(
    from table: TOMLTable,
    path: String,
    fallback: BuiltinWidgetPlacement,
    allowGroupReference: Bool = true
  ) throws -> BuiltinWidgetPlacement {
    let rawGroup =
      try optionalString(table["group"], path: "\(path).group")
      ?? fallback.group

    return BuiltinWidgetPlacement(
      enabled: try optionalBool(table["enabled"], path: "\(path).enabled") ?? fallback.enabled,
      position: try parsePosition(
        try optionalString(table["position"], path: "\(path).position")
          ?? fallback.position.rawValue,
        path: "\(path).position"
      ),
      order: try optionalInt(table["order"], path: "\(path).order") ?? fallback.order,
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
      icon: try optionalString(table["icon"], path: "\(path).icon") ?? fallback.icon,
      textColorHex: try optionalString(table["text_color"], path: "\(path).text_color")
        ?? fallback.textColorHex,
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(path).background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(table["border_color"], path: "\(path).border_color")
        ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(table["border_width"], path: "\(path).border_width")
        ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(table["corner_radius"], path: "\(path).corner_radius")
        ?? fallback.cornerRadius,
      marginX: try optionalNumber(table["margin_x"], path: "\(path).margin_x") ?? fallback.marginX,
      marginY: try optionalNumber(table["margin_y"], path: "\(path).margin_y") ?? fallback.marginY,
      paddingX: try optionalNumber(table["padding_x"], path: "\(path).padding_x")
        ?? fallback.paddingX,
      paddingY: try optionalNumber(table["padding_y"], path: "\(path).padding_y")
        ?? fallback.paddingY,
      spacing: try optionalNumber(table["spacing"], path: "\(path).spacing") ?? fallback.spacing,
      opacity: try optionalNumber(table["opacity"], path: "\(path).opacity") ?? fallback.opacity
    )
  }

  /// Parses one tooltip/popup style block shared by simple built-ins.
  func parseBuiltinPopupStyle(
    from table: TOMLTable,
    path: String,
    fallback: BuiltinPopupStyle
  ) throws -> BuiltinPopupStyle {
    BuiltinPopupStyle(
      textColorHex: try optionalString(table["text_color"], path: "\(path).text_color")
        ?? fallback.textColorHex,
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(path).background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(table["border_color"], path: "\(path).border_color")
        ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(table["border_width"], path: "\(path).border_width")
        ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(table["corner_radius"], path: "\(path).corner_radius")
        ?? fallback.cornerRadius,
      paddingX: try optionalNumber(table["padding_x"], path: "\(path).padding_x")
        ?? fallback.paddingX,
      paddingY: try optionalNumber(table["padding_y"], path: "\(path).padding_y")
        ?? fallback.paddingY,
      marginX: try optionalNumber(table["margin_x"], path: "\(path).margin_x") ?? fallback.marginX,
      marginY: try optionalNumber(table["margin_y"], path: "\(path).margin_y") ?? fallback.marginY
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

  /// Returns the legacy boolean logging override mapped into a log level.
  func legacyConfigLogLevel(from table: TOMLTable) -> ProcessLogLevel? {
    guard let debugEnabled = table["debug"]?.bool else {
      return nil
    }

    return debugEnabled ? .debug : .info
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

  /// Parses one Wi-Fi display mode.
  func parseWiFiDisplayMode(
    _ value: String,
    path: String
  ) throws -> BuiltinWiFiDisplayMode {
    try parseStringEnum(
      value,
      as: BuiltinWiFiDisplayMode.self,
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

  func requiredNumber(_ value: any TOMLValueConvertible, path: String) throws -> Double {
    if let double = value.double {
      return double
    }

    if let int = value.int {
      return Double(int)
    }

    throw ConfigError.invalidType(
      path: path,
      expected: "number",
      actual: describe(value)
    )
  }

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

  func optionalString(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
    guard let value else { return nil }
    return try requiredString(value, path: path)
  }

  func optionalBool(_ value: (any TOMLValueConvertible)?, path: String) throws -> Bool? {
    guard let value else { return nil }
    return try requiredBool(value, path: path)
  }

  func optionalInt(_ value: (any TOMLValueConvertible)?, path: String) throws -> Int? {
    guard let value else { return nil }
    return try requiredInt(value, path: path)
  }

  func optionalNumber(_ value: (any TOMLValueConvertible)?, path: String) throws -> Double? {
    guard let value else { return nil }
    return try requiredNumber(value, path: path)
  }

  func optionalStringArray(_ value: (any TOMLValueConvertible)?, path: String) throws -> [String]? {
    guard let value else { return nil }
    return try requiredStringArray(value, path: path)
  }

  func optionalStringTable(
    _ value: (any TOMLValueConvertible)?,
    path: String
  ) throws -> [String: String]? {
    guard let value else { return nil }
    return try requiredStringTable(value, path: path)
  }

  /// Parses one optional path string and expands `~` when present.
  func optionalExpandedPath(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
    expandedPath(try optionalString(value, path: path))
  }
}
