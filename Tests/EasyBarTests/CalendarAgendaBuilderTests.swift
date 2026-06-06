import EasyBarShared
import XCTest

@testable import EasyBarCalendarPresentation

final class CalendarAgendaBuilderTests: XCTestCase {
  func testCalendarDateFormatterUsesProvidedCalendarAndFormat() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 2 * 60 * 60) ?? .gmt

    let date = Date(timeIntervalSince1970: 0)

    XCTAssertEqual(
      CalendarDateFormatter.string(from: date, calendar: calendar, dateFormat: "HH:mm"),
      "02:00"
    )
  }

  func testCalendarDateFormatterUsesProvidedLocaleForTemplates() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

    let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let locale = Locale(identifier: "de_CH")

    let expectedFormatter = DateFormatter()
    expectedFormatter.calendar = calendar
    expectedFormatter.timeZone = calendar.timeZone
    expectedFormatter.locale = locale
    expectedFormatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")

    XCTAssertEqual(
      CalendarDateFormatter.localizedString(
        from: date,
        calendar: calendar,
        locale: locale,
        template: "LLLL yyyy"
      ),
      expectedFormatter.string(from: date)
    )
  }

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
