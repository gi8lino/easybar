import XCTest

@testable import EasyBarApp

final class WidgetScrollDirectionResolverTests: XCTestCase {
  func testVerticalDeltaResolvesDirection() {
    XCTAssertEqual(WidgetScrollDirectionResolver.resolve(deltaY: 1), .up)
    XCTAssertEqual(WidgetScrollDirectionResolver.resolve(deltaY: -1), .down)
  }

  func testZeroAndNonFiniteDeltaDoNotResolveDirection() {
    XCTAssertNil(WidgetScrollDirectionResolver.resolve(deltaY: 0))
    XCTAssertNil(WidgetScrollDirectionResolver.resolve(deltaY: .nan))
    XCTAssertNil(WidgetScrollDirectionResolver.resolve(deltaY: .infinity))
  }
}
