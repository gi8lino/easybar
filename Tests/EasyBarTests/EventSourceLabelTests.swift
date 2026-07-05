import XCTest

@testable import EasyBarApp

final class EventSourceLabelTests: XCTestCase {
  func testAeroSpaceSubscriptionSourceUsesEventName() {
    XCTAssertEqual(
      EventSourceLabel.aerospaceSubscribe("focused-workspace-changed"),
      "aerospace subscribe focused-workspace-changed"
    )
  }

  func testRuntimeManualRefreshSourceMatchesEventName() {
    XCTAssertEqual(EventSourceLabel.runtimeManualRefresh, "runtime manual_refresh")
  }
}
