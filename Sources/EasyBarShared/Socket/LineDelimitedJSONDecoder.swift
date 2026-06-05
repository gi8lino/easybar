import Foundation

/// Incrementally decodes newline-delimited JSON messages from arbitrary byte chunks.
public struct LineDelimitedJSONDecoder<Message: Decodable> {
  private var pending = Data()
  private let decoder: JSONDecoder

  /// Creates a new line-delimited decoder.
  public init(decoder: JSONDecoder? = nil) {
    self.decoder = decoder ?? Self.makeDefaultDecoder()
  }

  /// Appends bytes and returns one result for each complete non-empty line.
  public mutating func append(_ bytes: ArraySlice<UInt8>) -> [Result<Message, Error>] {
    pending.append(contentsOf: bytes)
    return decodePendingLines()
  }

  /// Decodes a final unterminated non-empty line, when one is pending.
  public mutating func flush() -> [Result<Message, Error>] {
    guard !pending.isEmpty else { return [] }

    let line = pending
    pending.removeAll()
    return [decode(line)]
  }

  private mutating func decodePendingLines() -> [Result<Message, Error>] {
    var results: [Result<Message, Error>] = []

    while let newlineIndex = pending.firstIndex(of: 0x0A) {
      let line = pending.prefix(upTo: newlineIndex)
      pending.removeSubrange(...newlineIndex)

      guard !line.isEmpty else { continue }
      results.append(decode(line))
    }

    return results
  }

  private func decode(_ data: Data.SubSequence) -> Result<Message, Error> {
    do {
      return .success(try decoder.decode(Message.self, from: Data(data)))
    } catch {
      return .failure(error)
    }
  }

  private static func makeDefaultDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
