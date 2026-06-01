import XCTest

@testable import EasyBarApp

final class WidgetTreeUpdateTests: XCTestCase {
  func testSupportedProtocolVersionIsAccepted() throws {
    let update = try JSONDecoder().decode(
      WidgetTreeUpdate.self,
      from: Data(#"{"protocol_version":1,"type":"ready"}"#.utf8)
    )

    XCTAssertTrue(update.isSupportedProtocolVersion)
  }

  func testUnexpectedProtocolVersionIsRejected() throws {
    let update = try JSONDecoder().decode(
      WidgetTreeUpdate.self,
      from: Data(#"{"protocol_version":2,"type":"ready"}"#.utf8)
    )

    XCTAssertFalse(update.isSupportedProtocolVersion)
  }

  func testClearRootPayloadIsDecoded() throws {
    let update = try JSONDecoder().decode(
      WidgetTreeUpdate.self,
      from: Data(#"{"protocol_version":1,"type":"clear_root","root":"clock"}"#.utf8)
    )

    XCTAssertTrue(update.isClearRoot)
    XCTAssertEqual(update.clearRootID, "clock")
  }
}
