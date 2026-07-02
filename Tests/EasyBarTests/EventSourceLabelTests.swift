import EasyBarShared
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

  func testSocketSourcesUseCommandRawValues() {
    XCTAssertEqual(EventSourceLabel.socket(.workspaceChanged), "socket workspace_changed")
    XCTAssertEqual(EventSourceLabel.socket(.focusChanged), "socket focus_changed")
    XCTAssertEqual(EventSourceLabel.socket(.spaceModeChanged), "socket space_mode_changed")
  }
}
