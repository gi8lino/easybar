import XCTest
@testable import EasyBar

final class EventCatalogTests: XCTestCase {
  func testLuaDefinitionsMatchSwiftCatalog() {
    XCTAssertEqual(EventCatalog.currentLuaDefinitionWarnings(), [])
  }

  func testSubscriptionPlanIncludesIntervalAndGroupedSources() {
    let plan = EventManager.subscriptionPlan(
      for: [
        AppEvent.chargingStateChange.rawValue,
        AppEvent.powerSourceChange.rawValue,
        AppEvent.secondTick.rawValue,
        "interval_tick:5",
      ]
    )

    XCTAssertEqual(plan.interval, 5)
    XCTAssertTrue(plan.sources.contains("powerSource"))
    XCTAssertTrue(plan.sources.contains("secondTick"))
    XCTAssertFalse(plan.sources.contains("minuteTick"))
  }
}
