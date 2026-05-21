import EasyBarShared
import XCTest

@testable import EasyBarCalendarPresentation

final class CalendarAgendaBuilderTests: XCTestCase {
  func testBuildUsesInjectedDisplayDateForGroupedSelections() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

    let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 23, minute: 30))!
    let end = calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 1, minute: 0))!
    let clampedDay = calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 0, minute: 0))!

    let event = CalendarAgentEvent(
      id: "event-1",
      eventIdentifier: "event-1",
      title: "Overnight",
      startDate: start,
      endDate: end,
      isAllDay: false,
      calendarID: nil,
      calendarName: nil,
      calendarColorHex: nil,
      location: nil,
      alertOffsetsSeconds: [],
      isHoliday: false,
      hasAlert: false,
      travelTimeSeconds: nil
    )

    let rows = CalendarAgendaBuilder.build(
      events: [event],
      selectionSpansMultipleDays: true,
      calendar: calendar,
      displayedDate: { _ in clampedDay }
    )

    XCTAssertEqual(rows.count, 2)
    XCTAssertEqual(rows.first?.id, "header-\(clampedDay.timeIntervalSince1970)")
  }
}
