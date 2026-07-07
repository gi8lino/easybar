import Foundation
import XCTest

@testable import EasyBarApp

final class AeroSpaceSubscriptionStreamBufferTests: XCTestCase {
  func testDropsOversizedCompleteLineBeforeDecoding() {
    var buffer = AeroSpaceSubscriptionStreamBuffer()
    var oversizedLine = Data(repeating: 0x61, count: 70 * 1024)
    oversizedLine.append(0x0A)

    let dropped = buffer.append(data: oversizedLine, stream: .output)

    XCTAssertTrue(dropped.droppedBuffer)
    XCTAssertEqual(dropped.lines, [])

    let next = buffer.append(data: Data("ok\n".utf8), stream: .output)

    XCTAssertFalse(next.droppedBuffer)
    XCTAssertEqual(next.lines, ["ok"])
  }

  func testDiscardsOversizedPartialLineUntilNextNewline() {
    var buffer = AeroSpaceSubscriptionStreamBuffer()
    let oversizedPartialLine = Data(repeating: 0x61, count: 70 * 1024)

    let dropped = buffer.append(data: oversizedPartialLine, stream: .output)

    XCTAssertTrue(dropped.droppedBuffer)
    XCTAssertEqual(dropped.lines, [])

    let recovery = buffer.append(data: Data("fragment-to-drop\nok\n".utf8), stream: .output)

    XCTAssertFalse(recovery.droppedBuffer)
    XCTAssertEqual(recovery.lines, ["ok"])
  }

  func testOversizedOutputDiscardDoesNotAffectErrorStream() {
    var buffer = AeroSpaceSubscriptionStreamBuffer()
    let oversizedPartialLine = Data(repeating: 0x61, count: 70 * 1024)

    _ = buffer.append(data: oversizedPartialLine, stream: .output)
    let error = buffer.append(data: Data("err\n".utf8), stream: .error)
    let output = buffer.append(data: Data("fragment-to-drop\nok\n".utf8), stream: .output)

    XCTAssertEqual(error.lines, ["err"])
    XCTAssertEqual(output.lines, ["ok"])
  }

}
