import XCTest

@testable import EasyBarApp

final class WidgetRenderMetricsTests: XCTestCase {
  func testDimensionRejectsNonFiniteAndClampsNegativeValues() {
    XCTAssertNil(WidgetRenderMetrics.dimension(nil))
    XCTAssertNil(WidgetRenderMetrics.dimension(.nan))
    XCTAssertNil(WidgetRenderMetrics.dimension(.infinity))
    XCTAssertEqual(WidgetRenderMetrics.dimension(-12), 0)
    XCTAssertEqual(WidgetRenderMetrics.dimension(12), 12)
  }

  func testPositiveUsesFallbackForInvalidValues() {
    XCTAssertEqual(WidgetRenderMetrics.positive(-1, fallback: 14), 14)
    XCTAssertEqual(WidgetRenderMetrics.positive(0, fallback: 14), 14)
    XCTAssertEqual(WidgetRenderMetrics.positive(.nan, fallback: 14), 14)
    XCTAssertEqual(WidgetRenderMetrics.positive(9, fallback: 14), 9)
  }

  func testOpacityIsFiniteAndClamped() {
    XCTAssertEqual(WidgetRenderMetrics.opacity(nil), 1)
    XCTAssertEqual(WidgetRenderMetrics.opacity(.nan), 1)
    XCTAssertEqual(WidgetRenderMetrics.opacity(-0.5), 0)
    XCTAssertEqual(WidgetRenderMetrics.opacity(0.4), 0.4)
    XCTAssertEqual(WidgetRenderMetrics.opacity(2), 1)
  }
}
