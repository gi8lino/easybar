import CoreGraphics
import XCTest

@testable import EasyBarApp
@testable import EasyBarCalendarConfig
@testable import EasyBarCalendarPresentation

final class CalendarMonthRangeBuilderTests: XCTestCase {
  func testVisibleGridRangeStartsAtWeekBoundaryAndEndsAfterLastVisibleWeek() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    calendar.firstWeekday = 2

    let visibleMonth = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
    let range = CalendarMonthRangeBuilder.visibleGridRange(for: visibleMonth, calendar: calendar)

    XCTAssertEqual(
      range?.start,
      calendar.date(from: DateComponents(year: 2026, month: 4, day: 27))
    )
    XCTAssertEqual(
      range?.end,
      calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))
    )
  }

  func testSubscriptionRangeExpandsWholeMonthsForRadius() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

    let visibleMonth = calendar.date(from: DateComponents(year: 2026, month: 5, day: 15))!
    let range = CalendarMonthRangeBuilder.subscriptionRange(
      for: visibleMonth,
      radius: 2,
      calendar: calendar
    )

    XCTAssertEqual(
      range?.start,
      calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))
    )
    XCTAssertEqual(
      range?.end,
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))
    )
  }

  func testPopupSurfaceSizeMatchesMode() {
    var config = CalendarBuiltinConfig.default

    XCTAssertEqual(config.popupMode, .month)
    XCTAssertEqual(config.popupSurfaceSize, CGSize(width: 560, height: 560))

    config.popupMode = .upcoming
    XCTAssertEqual(config.popupSurfaceSize, CGSize(width: 360, height: 520))

    config.popupMode = .none
    XCTAssertEqual(config.popupSurfaceSize, CGSize(width: 280, height: 96))
  }
}
