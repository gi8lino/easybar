import XCTest

@testable import EasyBar

final class CalendarSurfaceMetricsTests: XCTestCase {
  func testBorderLineWidthAllowsZeroToHideBorder() {
    XCTAssertEqual(CalendarSurfaceMetrics.borderLineWidth(0), 0)
  }

  func testBorderLineWidthPreservesPositiveWidths() {
    XCTAssertEqual(CalendarSurfaceMetrics.borderLineWidth(2.5), 2.5)
  }

  func testBorderLineWidthClampsNegativeWidthsToZero() {
    XCTAssertEqual(CalendarSurfaceMetrics.borderLineWidth(-3), 0)
  }
}
