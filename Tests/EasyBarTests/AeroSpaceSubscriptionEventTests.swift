import Foundation
import XCTest

@testable import EasyBarApp

final class AeroSpaceSubscriptionEventTests: XCTestCase {
  func testDecodeParsesAeroSpaceEventName() throws {
    let event = try JSONDecoder().decode(
      AeroSpaceSubscriptionEvent.self,
      from: Data(#"{"_event":"focused-workspace-changed","workspace":"2"}"#.utf8)
    )

    XCTAssertEqual(event.name, AeroSpaceSubscriptionEvent.Name.focusedWorkspaceChanged)
    XCTAssertEqual(event.appEvent, .workspaceChange)
  }

  func testAppEventMappingCoversSemanticEasyBarEvents() {
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.focusChanged).appEvent,
      .focusChange
    )
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.focusedWorkspaceChanged)
        .appEvent,
      .workspaceChange
    )
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.focusedMonitorChanged)
        .appEvent,
      .workspaceChange
    )
    XCTAssertNil(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.modeChanged).appEvent
    )
    XCTAssertNil(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.windowDetected).appEvent
    )
    XCTAssertNil(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.bindingTriggered).appEvent
    )
  }

  func testSubscribeArgumentsUseAllEventsAndInitialState() {
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent.subscribeArguments,
      ["subscribe", "--all"]
    )
  }

  func testBindingTriggeredUsesLongerRefreshDelay() {
    XCTAssertGreaterThan(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.bindingTriggered)
        .refreshDelayNanoseconds,
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.focusChanged)
        .refreshDelayNanoseconds
    )
  }

  func testStateChangeEventsRefreshImmediately() {
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.focusChanged)
        .refreshDelayNanoseconds,
      0
    )
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.focusedWorkspaceChanged)
        .refreshDelayNanoseconds,
      0
    )
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.windowDetected)
        .refreshDelayNanoseconds,
      0
    )
    XCTAssertEqual(
      AeroSpaceSubscriptionEvent(name: AeroSpaceSubscriptionEvent.Name.modeChanged)
        .refreshDelayNanoseconds,
      0
    )
  }
}
