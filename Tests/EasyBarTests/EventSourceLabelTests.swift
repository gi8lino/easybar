import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

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

  func testScriptSourceUsesEventCommandName() {
    XCTAssertEqual(EventSourceLabel.script(.workspaceChange), "script workspace_change")
  }
}
