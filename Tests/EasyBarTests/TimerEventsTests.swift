import EasyBarShared
import XCTest

@testable import EasyBarApp

@MainActor
final class TimerEventsTests: XCTestCase {
  /// Verifies that separate intervals for one widget retain separate timer handles.
  func testRetainsDistinctSchedulesForSameWidget() {
    let eventHub = EventHub(
      logger: ProcessLogger(label: "timer-events.test", minimumLevel: .error),
      enqueueLuaEvent: { _ in }
    )
    let timerEvents = TimerEvents(
      logger: ProcessLogger(label: "timer-events.test", minimumLevel: .error),
      eventHub: eventHub
    )
    let schedules: Set<WidgetIntervalSchedule> = [
      WidgetIntervalSchedule(widgetID: "clock", interval: 3_600),
      WidgetIntervalSchedule(widgetID: "clock", interval: 7_200),
    ]

    timerEvents.replaceIntervalTimers(schedules: schedules)
    defer { timerEvents.stopAll() }

    XCTAssertEqual(timerEvents.activeIntervalSchedules, schedules)
  }
}
