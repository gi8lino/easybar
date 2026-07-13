import XCTest

@testable import EasyBarApp

final class SliderValueRangeTests: XCTestCase {
  func testReversedBoundsAreOrdered() {
    let range = SliderValueRange(minimum: 100, maximum: 0, step: 1)

    XCTAssertEqual(range.lowerBound, 0)
    XCTAssertEqual(range.upperBound, 100)
  }

  func testEqualBoundsReceiveMinimumSpan() {
    let range = SliderValueRange(minimum: 5, maximum: 5, step: 0)

    XCTAssertEqual(range.lowerBound, 5)
    XCTAssertEqual(range.upperBound, 5 + SliderValueRange.minimumSpan)
    XCTAssertEqual(range.step, SliderValueRange.minimumSpan)
  }

  func testNonFiniteInputsAndValuesUseSafeDefaults() {
    let range = SliderValueRange(minimum: .nan, maximum: .infinity, step: .nan)

    XCTAssertEqual(range, SliderValueRange(minimum: 0, maximum: 100, step: 0))
    XCTAssertEqual(range.clamped(.nan), 0)
    XCTAssertEqual(range.clamped(200), 100)
  }
}
