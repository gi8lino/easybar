import Foundation

/// One typed network-agent field value sent over the wire.
public enum NetworkAgentFieldValue: Codable, Equatable {
  case string(String)
  case bool(Bool)
  case int(Int)
  case double(Double)
  case stringList([String])

  /// Returns the wrapped string value when present.
  public var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  /// Returns the wrapped boolean value when present.
  public var boolValue: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  /// Returns the wrapped integer value when present.
  public var intValue: Int? {
    guard case .int(let value) = self else { return nil }
    return value
  }

  /// Returns the wrapped double value when present.
  public var doubleValue: Double? {
    guard case .double(let value) = self else { return nil }
    return value
  }

  /// Returns the wrapped string-list value when present.
  public var stringListValue: [String]? {
    guard case .stringList(let value) = self else { return nil }
    return value
  }

  /// Decodes one typed field value from a plain JSON scalar or string array.
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
      return
    }

    if let value = try? container.decode(Int.self) {
      self = .int(value)
      return
    }

    if let value = try? container.decode(Double.self) {
      self = .double(value)
      return
    }

    if let value = try? container.decode([String].self) {
      self = .stringList(value)
      return
    }

    self = .string(try container.decode(String.self))
  }

  /// Encodes one typed field value as a plain JSON scalar or string array.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .bool(let value):
      try container.encode(value)
    case .int(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .stringList(let value):
      try container.encode(value)
    }
  }
}
