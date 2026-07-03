import CoreGraphics
import XCTest

@testable import EasyBarApp

final class SliderWidthResolverTests: XCTestCase {
  /// Verifies that positive explicit widths are preserved.
  func testResolveUsesPositiveExplicitWidth() {
    XCTAssertEqual(
      SliderWidthResolver.resolve(explicitWidth: 80, fallback: 140),
      80
    )
  }

  /// Verifies that invalid explicit widths fall back to the caller default.
  func testResolveFallsBackForInvalidExplicitWidth() {
    XCTAssertEqual(
      SliderWidthResolver.resolve(explicitWidth: -1, fallback: 140),
      140
    )
    XCTAssertEqual(
      SliderWidthResolver.resolve(explicitWidth: 0, fallback: 140),
      140
    )
    XCTAssertEqual(
      SliderWidthResolver.resolve(explicitWidth: .infinity, fallback: 140),
      140
    )
  }

  /// Verifies that the resolver never returns an invalid frame width.
  func testResolveUsesMinimumWidthForInvalidFallback() {
    XCTAssertEqual(
      SliderWidthResolver.resolve(explicitWidth: nil, fallback: .nan),
      1
    )
  }
}
