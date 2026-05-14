import XCTest

@testable import EasyBar

final class MonthPopupViewHelperTests: XCTestCase {
  func testFormatVisibleMonthTitleHonorsProvidedLocale() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

    let date = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let locale = Locale(identifier: "de_CH")

    let expectedFormatter = DateFormatter()
    expectedFormatter.calendar = calendar
    expectedFormatter.locale = locale
    expectedFormatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")

    XCTAssertEqual(
      NativeMonthCalendarPopupView.formatVisibleMonthTitle(date, calendar: calendar, locale: locale),
      expectedFormatter.string(from: date)
    )
  }
}
