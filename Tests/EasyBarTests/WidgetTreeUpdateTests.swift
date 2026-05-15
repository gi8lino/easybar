import XCTest

@testable import EasyBar

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
}
