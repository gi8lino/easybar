import Foundation
import TOMLKit

extension Config {

  /// Parses one placement block.
  func parseBuiltinPlacement(
    from table: TOMLTable,
    path: String,
    fallback: BuiltinWidgetPlacement
  ) throws -> BuiltinWidgetPlacement {
    return BuiltinWidgetPlacement(
      enabled: try optionalBool(table["enabled"], path: "\(path).enabled") ?? fallback.enabled,
      position: normalizedPosition(
        try optionalString(table["position"], path: "\(path).position")
          ?? fallback.position.rawValue
      ),
      order: try optionalInt(table["order"], path: "\(path).order") ?? fallback.order,
      group: try optionalString(table["group"], path: "\(path).group") ?? fallback.group
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
        table["background_color"], path: "\(path).background_color") ?? fallback.backgroundColorHex,
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

  /// Parses one battery color mode.
  func normalizedBatteryColorMode(_ value: String) -> BuiltinBatteryColorMode {
    BuiltinBatteryColorMode(rawValue: value) ?? .dynamic
  }

  /// Parses one battery display mode.
  func normalizedBatteryDisplayMode(_ value: String) -> BuiltinBatteryDisplayMode {
    BuiltinBatteryDisplayMode(rawValue: value) ?? .expand
  }

  /// Parses one calendar popup mode.
  func normalizedCalendarPopupMode(_ value: String) -> CalendarPopupMode {
    CalendarPopupMode(rawValue: value) ?? .upcoming
  }

  func normalizedPosition(_ value: String) -> WidgetPosition {
    WidgetPosition(rawValue: value) ?? .right
  }

  func normalizedCalendarLayout(_ value: String) -> CalendarAnchorLayout {
    CalendarAnchorLayout(rawValue: value) ?? .item
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
}
