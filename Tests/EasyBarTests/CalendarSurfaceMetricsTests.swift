import XCTest

@testable import EasyBarCalendarUI

final class CalendarSurfaceMetricsTests: XCTestCase {
  func testBorderLineWidthAllowsZeroToHideBorder() {
    XCTAssertEqual(CalendarUIPrimitives.borderLineWidth(0), 0)
  }

  func testBorderLineWidthPreservesPositiveWidths() {
    XCTAssertEqual(CalendarUIPrimitives.borderLineWidth(2.5), 2.5)
  }

  func testBorderLineWidthClampsNegativeWidthsToZero() {
    XCTAssertEqual(CalendarUIPrimitives.borderLineWidth(-3), 0)
  }
}
