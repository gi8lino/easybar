import Foundation
import TOMLKit

/// Small explicit TOML reader for default-backed app configuration.
public struct TOMLConfigReader<Failure: Error> {
  private let table: TOMLTable
  private let path: String
  private let makeInvalidTypeError: (String, String, String) -> Failure
  private let makeInvalidValueError: (String, String) -> Failure

  /// Creates a reader for one TOML table and config path.
  public init(
    table: TOMLTable,
    path: String,
    makeInvalidTypeError: @escaping (String, String, String) -> Failure,
    makeInvalidValueError: @escaping (String, String) -> Failure
  ) {
    self.table = table
    self.path = path
    self.makeInvalidTypeError = makeInvalidTypeError
    self.makeInvalidValueError = makeInvalidValueError
  }

  /// Returns the underlying TOML table for interop with reusable parsers.
  public var rawTable: TOMLTable {
    table
  }

  /// Returns whether this reader's TOML table has no configured keys.
  public var isEmpty: Bool {
    table.isEmpty
  }

  /// Returns the sorted keys in this reader's TOML table.
  public var keys: [String] {
    table.keys.sorted()
  }

  /// Returns whether this reader contains one key.
  public func contains(_ key: String) -> Bool {
    table[key] != nil
  }

  /// Returns one nested section reader. Missing sections are treated as empty tables.
  public func section(_ keyPath: String) throws -> TOMLConfigReader<Failure> {
    var reader = self

    for key in splitKeyPath(keyPath) {
      reader = try reader.directSection(key)
    }

    return reader
  }

  /// Returns one nested section reader when present, or nil when absent.
  public func optionalSection(_ keyPath: String) throws -> TOMLConfigReader<Failure>? {
    var reader = self

    for key in splitKeyPath(keyPath) {
      guard let next = try reader.optionalDirectSection(key) else {
        return nil
      }
      reader = next
    }

    return reader
  }

  /// Returns the full config path for one key in this reader.
  public func path(for key: String) -> String {
    return path.isEmpty ? key : "\(path).\(key)"
  }

  /// Returns a string value or the fallback when absent.
  public func string(_ key: String, fallback: String) throws -> String {
    try optionalString(key, fallback: fallback) ?? fallback
  }

  /// Returns an optional string value or the optional fallback when absent.
  public func optionalString(_ key: String, fallback: String? = nil) throws -> String? {
    guard let value = table[key] else { return fallback }
    return try requiredString(value, path: path(for: key))
  }

  /// Returns a boolean value or the fallback when absent.
  public func bool(_ key: String, fallback: Bool) throws -> Bool {
    try optionalBool(key, fallback: fallback) ?? fallback
  }

  /// Returns an optional boolean value or the optional fallback when absent.
  public func optionalBool(_ key: String, fallback: Bool? = nil) throws -> Bool? {
    guard let value = table[key] else { return fallback }
    return try requiredBool(value, path: path(for: key))
  }

  /// Returns an integer value for one key, or the fallback when the key is absent.
  ///
  /// Bounds are inclusive. `minimum` accepts values greater than or equal to the bound,
  /// and `maximum` accepts values less than or equal to the bound. Bounds are checked
  /// after resolving the fallback.
  ///
  /// - Parameters:
  ///   - key: Key in this reader's TOML table.
  ///   - fallback: Value used when `key` is absent.
  ///   - minimum: Optional inclusive lower bound for the resolved value.
  ///   - maximum: Optional inclusive upper bound for the resolved value.
  /// - Returns: The configured integer, or `fallback` when absent.
  public func int(
    _ key: String,
    fallback: Int,
    minimum: Int? = nil,
    maximum: Int? = nil
  ) throws -> Int {
    try optionalInt(
      key,
      fallback: fallback,
      minimum: minimum,
      maximum: maximum
    ) ?? fallback
  }

  /// Returns an optional integer value for one key, or the optional fallback when absent.
  ///
  /// Bounds are inclusive. `minimum` accepts values greater than or equal to the bound,
  /// and `maximum` accepts values less than or equal to the bound. Bounds are checked
  /// after resolving the fallback. When both the TOML key and fallback are absent, this
  /// returns `nil` without applying bounds.
  ///
  /// - Parameters:
  ///   - key: Key in this reader's TOML table.
  ///   - fallback: Optional value used when `key` is absent.
  ///   - minimum: Optional inclusive lower bound for the resolved value.
  ///   - maximum: Optional inclusive upper bound for the resolved value.
  /// - Returns: The configured integer, `fallback`, or `nil` when both are absent.
  public func optionalInt(
    _ key: String,
    fallback: Int? = nil,
    minimum: Int? = nil,
    maximum: Int? = nil
  ) throws -> Int? {
    let value: Int

    if let configuredValue = table[key] {
      value = try requiredInt(configuredValue, path: path(for: key))
    } else if let fallback {
      value = fallback
    } else {
      return nil
    }

    return try validateBounds(
      value,
      path: path(for: key),
      minimum: minimum,
      maximum: maximum,
      describe: { String($0) }
    )
  }

  /// Returns a finite number value for one key, or the fallback when the key is absent.
  ///
  /// Integer TOML values are accepted and converted to `Double`. The resolved value
  /// must be finite before inclusive bounds are checked. `minimum` accepts values
  /// greater than or equal to the bound, and `maximum` accepts values less than or
  /// equal to the bound.
  ///
  /// - Parameters:
  ///   - key: Key in this reader's TOML table.
  ///   - fallback: Value used when `key` is absent.
  ///   - minimum: Optional inclusive lower bound for the resolved value.
  ///   - maximum: Optional inclusive upper bound for the resolved value.
  /// - Returns: The configured number, or `fallback` when absent.
  public func double(
    _ key: String,
    fallback: Double,
    minimum: Double? = nil,
    maximum: Double? = nil
  ) throws -> Double {
    try optionalDouble(
      key,
      fallback: fallback,
      minimum: minimum,
      maximum: maximum
    ) ?? fallback
  }

  /// Returns an optional finite number value for one key, or the optional fallback when absent.
  ///
  /// Integer TOML values are accepted and converted to `Double`. The resolved value
  /// must be finite before inclusive bounds are checked. When both the TOML key and
  /// fallback are absent, this returns `nil` without applying bounds.
  ///
  /// - Parameters:
  ///   - key: Key in this reader's TOML table.
  ///   - fallback: Optional value used when `key` is absent.
  ///   - minimum: Optional inclusive lower bound for the resolved value.
  ///   - maximum: Optional inclusive upper bound for the resolved value.
  /// - Returns: The configured number, `fallback`, or `nil` when both are absent.
  public func optionalDouble(
    _ key: String,
    fallback: Double? = nil,
    minimum: Double? = nil,
    maximum: Double? = nil
  ) throws -> Double? {
    let value: Double

    if let configuredValue = table[key] {
      value = try requiredDouble(configuredValue, path: path(for: key))
    } else if let fallback {
      value = fallback
    } else {
      return nil
    }

    return try validateBounds(
      value,
      path: path(for: key),
      minimum: minimum,
      maximum: maximum,
      describe: describeNumberBound
    )
  }

  /// Returns a string array value or the fallback when absent.
  public func stringArray(_ key: String, fallback: [String]) throws -> [String] {
    try optionalStringArray(key, fallback: fallback) ?? fallback
  }

  /// Returns an optional string array value or the optional fallback when absent.
  public func optionalStringArray(_ key: String, fallback: [String]? = nil) throws -> [String]? {
    guard let value = table[key] else { return fallback }
    return try requiredStringArray(value, path: path(for: key))
  }

  /// Returns the current table as a string map, merged over the fallback.
  public func stringTable(fallback: [String: String]) throws -> [String: String] {
    guard !table.isEmpty else { return fallback }

    var values = fallback
    for key in keys {
      guard let value = table[key] else { continue }
      values[key] = try requiredString(value, path: path(for: key))
    }

    return values
  }

  /// Returns a string table value or the fallback when absent.
  public func stringTable(_ key: String, fallback: [String: String]) throws -> [String: String] {
    try optionalStringTable(key, fallback: fallback) ?? fallback
  }

  /// Returns an optional string table value or the optional fallback when absent.
  public func optionalStringTable(
    _ key: String,
    fallback: [String: String]? = nil
  ) throws -> [String: String]? {
    guard let value = table[key] else { return fallback }
    return try requiredStringTable(value, path: path(for: key))
  }

  /// Returns a string-backed enum value or the fallback when absent.
  public func `enum`<Value: TOMLStringDecodable>(
    _ key: String,
    fallback: Value
  ) throws -> Value {
    try optionalEnum(key, fallback: fallback) ?? fallback
  }

  /// Returns an optional string-backed enum value or the optional fallback when absent.
  public func optionalEnum<Value: TOMLStringDecodable>(
    _ key: String,
    fallback: Value? = nil
  ) throws -> Value? {
    guard let rawValue = try optionalString(key) else { return fallback }
    let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if let value = Value(rawValue: normalized) {
      return value
    }

    throw makeInvalidValueError(
      path(for: key),
      "expected one of \(Value.allowedValues.joined(separator: ", "))"
    )
  }

  private func optionalDirectSection(_ key: String) throws -> TOMLConfigReader<Failure>? {
    guard table[key] != nil else { return nil }
    return try directSection(key)
  }

  private func directSection(_ key: String) throws -> TOMLConfigReader<Failure> {
    guard let value = table[key] else {
      return child(table: TOMLTable(), key: key)
    }

    guard let nestedTable = value.table else {
      throw makeInvalidTypeError(path(for: key), "table", describe(value))
    }

    return child(table: nestedTable, key: key)
  }

  private func child(table: TOMLTable, key: String) -> TOMLConfigReader<Failure> {
    TOMLConfigReader<Failure>(
      table: table,
      path: path(for: key),
      makeInvalidTypeError: makeInvalidTypeError,
      makeInvalidValueError: makeInvalidValueError
    )
  }

  private func splitKeyPath(_ keyPath: String) -> [String] {
    keyPath.split(separator: ".").map(String.init)
  }

  private func validateBounds<Value: Comparable>(
    _ value: Value,
    path: String,
    minimum: Value?,
    maximum: Value?,
    describe: (Value) -> String
  ) throws -> Value {
    if let minimum, value < minimum {
      throw makeInvalidValueError(
        path,
        boundsMessage(minimum: minimum, maximum: maximum, describe: describe)
      )
    }

    if let maximum, value > maximum {
      throw makeInvalidValueError(
        path,
        boundsMessage(minimum: minimum, maximum: maximum, describe: describe)
      )
    }

    return value
  }

  private func boundsMessage<Value>(
    minimum: Value?,
    maximum: Value?,
    describe: (Value) -> String
  ) -> String {
    switch (minimum, maximum) {
    case (.some(let minimum), .some(let maximum)):
      return "expected a value from \(describe(minimum)) to \(describe(maximum))"

    case (.some(let minimum), nil):
      return "expected a value greater than or equal to \(describe(minimum))"

    case (nil, .some(let maximum)):
      return "expected a value less than or equal to \(describe(maximum))"

    case (nil, nil):
      return "expected a valid value"
    }
  }

  private func describeNumberBound(_ value: Double) -> String {
    if value.rounded(.towardZero) == value {
      return String(Int(value))
    }

    return String(value)
  }

  private func requiredString(_ value: any TOMLValueConvertible, path: String) throws -> String {
    if let string = value.string {
      return string
    }

    throw makeInvalidTypeError(path, "string", describe(value))
  }

  private func requiredBool(_ value: any TOMLValueConvertible, path: String) throws -> Bool {
    if let bool = value.bool {
      return bool
    }

    throw makeInvalidTypeError(path, "bool", describe(value))
  }

  private func requiredInt(_ value: any TOMLValueConvertible, path: String) throws -> Int {
    if let int = value.int {
      return int
    }

    throw makeInvalidTypeError(path, "integer", describe(value))
  }

  private func requiredDouble(_ value: any TOMLValueConvertible, path: String) throws -> Double {
    let number: Double

    if let double = value.double {
      number = double
    } else if let int = value.int {
      number = Double(int)
    } else {
      throw makeInvalidTypeError(path, "number", describe(value))
    }

    guard number.isFinite else {
      throw makeInvalidValueError(path, "expected a finite number")
    }

    return number
  }

  private func requiredStringArray(
    _ value: any TOMLValueConvertible,
    path: String
  ) throws -> [String] {
    guard let array = value.array else {
      throw makeInvalidTypeError(path, "array", describe(value))
    }

    return try array.enumerated().map { index, entry in
      try requiredString(entry, path: "\(path)[\(index)]")
    }
  }

  private func requiredStringTable(
    _ value: any TOMLValueConvertible,
    path: String
  ) throws -> [String: String] {
    guard let table = value.table else {
      throw makeInvalidTypeError(path, "table", describe(value))
    }

    return try table.reduce(into: [String: String]()) { result, entry in
      let (key, value) = entry
      result[key] = try requiredString(value, path: "\(path).\(key)")
    }
  }

  private func describe(_ value: any TOMLValueConvertible) -> String {
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
}
