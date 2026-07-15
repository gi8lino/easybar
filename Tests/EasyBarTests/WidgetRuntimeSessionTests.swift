import XCTest

@testable import EasyBarApp

final class WidgetRuntimeSessionTests: XCTestCase {
  func testBeginningNewSessionRejectsWorkFromPreviousSession() {
    var session = WidgetRuntimeSession()
    let first = session.begin()
    let second = session.begin()

    XCTAssertFalse(session.accepts(first, whileRunning: true))
    XCTAssertTrue(session.accepts(second, whileRunning: true))
  }

  func testInvalidationRejectsQueuedWorkBeforeNextStart() {
    var session = WidgetRuntimeSession()
    let active = session.begin()

    session.invalidate()

    XCTAssertFalse(session.accepts(active, whileRunning: true))
  }

  func testStoppedRuntimeRejectsCurrentSession() {
    var session = WidgetRuntimeSession()
    let active = session.begin()

    XCTAssertFalse(session.accepts(active, whileRunning: false))
  }
}
