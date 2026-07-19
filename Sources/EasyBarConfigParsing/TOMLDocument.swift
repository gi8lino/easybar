import CEasyBarTOML
import Foundation

/// A TOML parsing failure reported by the lossless native parser.
public struct TOMLParseError: Error, LocalizedError, CustomStringConvertible {
  public let message: String
  public let start: Int?
  public let end: Int?
  public let line: Int?
  public let column: Int?

  public var errorDescription: String? { description }
  public var description: String {
    guard let line, let column else { return message }
    return message + " at line " + String(line) + ", column " + String(column)
  }
}

/// A typed TOML value used by EasyBar's configuration readers.
public enum TOMLValue: Sendable, Equatable {
  case table(TOMLTable)
  case array([TOMLValue])
  case string(String)
  case integer(Int)
  case double(Double)
  case bool(Bool)
  case datetime(String)

  public var table: TOMLTable? {
    guard case .table(let value) = self else { return nil }
    return value
  }

  public var array: [TOMLValue]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  public var string: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  public var int: Int? {
    guard case .integer(let value) = self else { return nil }
    return value
  }

  public var double: Double? {
    guard case .double(let value) = self else { return nil }
    return value
  }

  public var bool: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }
}

/// A TOML table parsed by the lossless `toml_edit` engine.
public struct TOMLTable: Sendable, Equatable, Sequence {
  private var values: [String: TOMLValue]

  public init() {
    values = [:]
  }

  public init(_ values: [String: TOMLValue]) {
    self.values = values
  }

  public init(string: String) throws {
    let response = try NativeTOMLBridge.parse(string)
    guard case .table(let table) = response else {
      throw TOMLParseError(
        message: "TOML root is not a table",
        start: nil,
        end: nil,
        line: nil,
        column: nil
      )
    }
    self = table
  }

  public var isEmpty: Bool { values.isEmpty }
  public var keys: Dictionary<String, TOMLValue>.Keys { values.keys }

  public subscript(key: String) -> TOMLValue? {
    values[key]
  }

  public func makeIterator() -> Dictionary<String, TOMLValue>.Iterator {
    values.makeIterator()
  }
}

/// One lossless TOML update applied by path.
public struct TOMLEdit: Sendable {
  public enum Value: Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case bool(Bool)
    case stringArray([String])
  }

  public let path: [String]
  public let value: Value

  public init(path: [String], value: Value) {
    self.path = path
    self.value = value
  }
}

/// Losslessly parses and edits TOML documents through `toml_edit`.
public enum TOMLDocument {
  public static func edit(_ text: String, edits: [TOMLEdit]) throws -> String {
    try NativeTOMLBridge.edit(text, edits: edits)
  }
}

private enum NativeTOMLBridge {
  static func parse(_ text: String) throws -> TOMLValue {
    let response = try call(text) { easybar_toml_parse($0) }
    if response["ok"] as? Bool == true, let value = response["value"] {
      return try decodeValue(value)
    }
    throw decodeError(response, source: text)
  }

  static func edit(_ text: String, edits: [TOMLEdit]) throws -> String {
    let request = ["edits": edits.map(editObject)]
    let requestData = try JSONSerialization.data(withJSONObject: request, options: [.sortedKeys])
    guard let requestJSON = String(data: requestData, encoding: .utf8) else {
      throw bridgeError("could not encode TOML edit request")
    }

    let response: [String: Any] = try text.withCString { input in
      try requestJSON.withCString { request in
        try decodeResponse(easybar_toml_edit(input, request))
      }
    }
    if response["ok"] as? Bool == true, let output = response["text"] as? String {
      return output
    }
    throw decodeError(response, source: text)
  }

  private static func call(
    _ text: String,
    operation: (UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
  ) throws -> [String: Any] {
    try text.withCString { try decodeResponse(operation($0)) }
  }

  private static func decodeResponse(
    _ pointer: UnsafeMutablePointer<CChar>?
  ) throws -> [String: Any] {
    guard let pointer else { throw bridgeError("native TOML parser returned no response") }
    defer { easybar_toml_string_free(pointer) }
    let data = Data(bytes: pointer, count: strlen(pointer))
    guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw bridgeError("native TOML parser returned an invalid response")
    }
    return response
  }

  private static func decodeValue(_ object: Any) throws -> TOMLValue {
    guard
      let object = object as? [String: Any],
      let kind = object["kind"] as? String,
      let value = object["value"]
    else { throw bridgeError("native TOML parser returned an invalid value") }

    switch kind {
    case "table":
      guard let entries = value as? [String: Any] else { throw bridgeError("invalid table") }
      return .table(TOMLTable(try entries.mapValues(decodeValue)))
    case "array":
      guard let entries = value as? [Any] else { throw bridgeError("invalid array") }
      return .array(try entries.map(decodeValue))
    case "string":
      guard let value = value as? String else { throw bridgeError("invalid string") }
      return .string(value)
    case "integer":
      guard let value = value as? NSNumber else { throw bridgeError("invalid integer") }
      return .integer(value.intValue)
    case "float":
      guard let value = value as? String, let number = Double(value) else {
        throw bridgeError("invalid float")
      }
      return .double(number)
    case "boolean":
      guard let value = value as? Bool else { throw bridgeError("invalid boolean") }
      return .bool(value)
    case "datetime":
      guard let value = value as? String else { throw bridgeError("invalid datetime") }
      return .datetime(value)
    default:
      throw bridgeError("native TOML parser returned unknown kind \(kind)")
    }
  }

  private static func editObject(_ edit: TOMLEdit) -> [String: Any] {
    let encoded: [String: Any]
    switch edit.value {
    case .string(let value): encoded = ["kind": "string", "value": value]
    case .integer(let value): encoded = ["kind": "integer", "value": value]
    case .double(let value): encoded = ["kind": "float", "value": value]
    case .bool(let value): encoded = ["kind": "boolean", "value": value]
    case .stringArray(let value): encoded = ["kind": "string_array", "value": value]
    }
    return ["path": edit.path, "value": encoded]
  }

  private static func decodeError(_ response: [String: Any], source: String) -> TOMLParseError {
    let error = response["error"] as? [String: Any]
    let start = (error?["start"] as? NSNumber)?.intValue
    let end = (error?["end"] as? NSNumber)?.intValue
    let location = start.map { sourceLocation(in: source, utf8Offset: $0) }
    return TOMLParseError(
      message: error?["message"] as? String ?? "unknown TOML error",
      start: start,
      end: end,
      line: location?.line,
      column: location?.column
    )
  }

  private static func sourceLocation(in source: String, utf8Offset: Int) -> (line: Int, column: Int) {
    let bytes = Array(source.utf8.prefix(max(0, utf8Offset)))
    let line = bytes.reduce(1) { $1 == 10 ? $0 + 1 : $0 }
    let column = bytes.lastIndex(of: 10).map { bytes.count - $0 } ?? (bytes.count + 1)
    return (line, column)
  }

  private static func bridgeError(_ message: String) -> TOMLParseError {
    TOMLParseError(message: message, start: nil, end: nil, line: nil, column: nil)
  }
}
