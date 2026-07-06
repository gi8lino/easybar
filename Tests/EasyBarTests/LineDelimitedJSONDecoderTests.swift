import EasyBarShared
import XCTest

final class LineDelimitedJSONDecoderTests: XCTestCase {
  private struct Message: Decodable, Equatable {
    let value: String
  }

  func testDecodesMessagesAcrossChunks() throws {
    var decoder = LineDelimitedJSONDecoder<Message>()

    XCTAssertTrue(decoder.append(bytes(#"{"value":"one"}"#)).isEmpty)

    let results = decoder.append(bytes("\n" + #"{"value":"two"}"# + "\n"))

    XCTAssertEqual(
      try decodedMessages(from: results),
      [
        Message(value: "one"),
        Message(value: "two"),
      ])
  }

  func testSkipsEmptyLinesAndFlushesTrailingLine() throws {
    var decoder = LineDelimitedJSONDecoder<Message>()

    let newlineResults = decoder.append(bytes("\n\n"))
    let trailingResults = decoder.append(bytes(#"{"value":"tail"}"#))
    let flushResults = decoder.flush()

    XCTAssertTrue(newlineResults.isEmpty)
    XCTAssertTrue(trailingResults.isEmpty)
    XCTAssertEqual(try decodedMessages(from: flushResults), [Message(value: "tail")])
    XCTAssertTrue(decoder.flush().isEmpty)
  }

  func testReturnsDecodeFailuresWithoutDroppingFollowingMessages() throws {
    var decoder = LineDelimitedJSONDecoder<Message>()

    let results = decoder.append(bytes(#"{"value":1}"# + "\n" + #"{"value":"ok"}"# + "\n"))

    XCTAssertEqual(results.count, 2)
    guard case .failure = results[0] else {
      return XCTFail("Expected first result to be a decode failure")
    }
    guard case .success(let message) = results[1] else {
      return XCTFail("Expected second result to decode successfully")
    }
    XCTAssertEqual(message, Message(value: "ok"))
  }

  func testRejectsOversizedUnterminatedLineAndDiscardsUntilNextNewline() throws {
    var decoder = LineDelimitedJSONDecoder<Message>(maxLineBytes: 16)

    let oversizedResults = decoder.append(bytes("12345678901234567"))
    XCTAssertEqual(oversizedResults.count, 1)
    guard case .failure(let error) = oversizedResults[0] else {
      return XCTFail("Expected an oversized-line failure")
    }
    XCTAssertEqual(
      error as? LineDelimitedJSONDecoderError,
      .lineTooLong(maxLineBytes: 16)
    )

    let recoveryResults = decoder.append(bytes("discarded\n" + #"{"value":"ok"}"# + "\n"))
    XCTAssertEqual(try decodedMessages(from: recoveryResults), [Message(value: "ok")])
  }

  private func bytes(_ string: String) -> ArraySlice<UInt8> {
    return Array(string.utf8)[...]
  }

  private func decodedMessages(from results: [Result<Message, Error>]) throws -> [Message] {
    return try results.map { try $0.get() }
  }
}
