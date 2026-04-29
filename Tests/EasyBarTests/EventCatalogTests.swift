import XCTest

@testable import EasyBar

final class EventCatalogTests: XCTestCase {
  func testLuaDefinitionsMatchSwiftCatalog() {
    XCTAssertEqual(EventCatalog.currentLuaDefinitionWarnings(), [])
  }

  func testLuaTokenNamesIncludeWidgetEventsAndForcedEvent() {
    XCTAssertTrue(EventCatalog.luaTokenEventNames.contains(EventCatalog.forcedEventName))
    XCTAssertTrue(EventCatalog.luaTokenEventNames.contains(WidgetEvent.mouseClicked.rawValue))
    XCTAssertTrue(EventCatalog.luaTokenEventNames.contains(WidgetEvent.sliderChanged.rawValue))
  }

  func testLuaTokenNamesExcludeInternalAppEvents() {
    XCTAssertFalse(EventCatalog.luaTokenEventNames.contains(AppEvent.manualRefresh.rawValue))
    XCTAssertFalse(EventCatalog.luaTokenEventNames.contains(AppEvent.intervalTick.rawValue))
  }

  func testLuaDriverNamesIncludeForcedEventAndExternalAppEvents() {
    XCTAssertTrue(EventCatalog.luaDriverEventNames.contains(EventCatalog.forcedEventName))
    XCTAssertTrue(EventCatalog.luaDriverEventNames.contains(AppEvent.systemWoke.rawValue))
    XCTAssertTrue(EventCatalog.luaDriverEventNames.contains(AppEvent.secondTick.rawValue))
  }

  func testLuaDriverNamesExcludeWidgetEventsAndInternalAppEvents() {
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(WidgetEvent.mouseClicked.rawValue))
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(WidgetEvent.sliderChanged.rawValue))
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(AppEvent.manualRefresh.rawValue))
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(AppEvent.intervalTick.rawValue))
  }

  @MainActor
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

  @MainActor
  func testSubscriptionPlanReturnsEmptyPlanForNoSubscriptions() {
    let plan = EventManager.subscriptionPlan(for: [])

    XCTAssertEqual(plan.sources, [])
    XCTAssertNil(plan.interval)
  }

  @MainActor
  func testSubscriptionPlanIncludesSystemSources() {
    let plan = EventManager.subscriptionPlan(
      for: [
        AppEvent.systemWoke.rawValue,
        AppEvent.sleep.rawValue,
        AppEvent.spaceChange.rawValue,
        AppEvent.appSwitch.rawValue,
        AppEvent.displayChange.rawValue,
      ]
    )

    XCTAssertTrue(plan.sources.contains("systemWake"))
    XCTAssertTrue(plan.sources.contains("sleep"))
    XCTAssertTrue(plan.sources.contains("spaceChange"))
    XCTAssertTrue(plan.sources.contains("appSwitch"))
    XCTAssertTrue(plan.sources.contains("displayChange"))
    XCTAssertNil(plan.interval)
  }

  @MainActor
  func testSubscriptionPlanGroupsPowerEventsIntoSinglePowerSource() {
    let plan = EventManager.subscriptionPlan(
      for: [
        AppEvent.powerSourceChange.rawValue,
        AppEvent.chargingStateChange.rawValue,
      ]
    )

    XCTAssertEqual(plan.sources, ["powerSource"])
    XCTAssertNil(plan.interval)
  }

  @MainActor
  func testSubscriptionPlanGroupsVolumeEventsIntoSingleVolumeSource() {
    let plan = EventManager.subscriptionPlan(
      for: [
        AppEvent.volumeChange.rawValue,
        AppEvent.muteChange.rawValue,
      ]
    )

    XCTAssertEqual(plan.sources, ["volume"])
    XCTAssertNil(plan.interval)
  }

  @MainActor
  func testSubscriptionPlanIncludesTimerSources() {
    let plan = EventManager.subscriptionPlan(
      for: [
        AppEvent.minuteTick.rawValue,
        AppEvent.secondTick.rawValue,
      ]
    )

    XCTAssertTrue(plan.sources.contains("minuteTick"))
    XCTAssertTrue(plan.sources.contains("secondTick"))
    XCTAssertNil(plan.interval)
  }

  @MainActor
  func testSubscriptionPlanParsesPositiveIntervalSubscription() {
    let plan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:2.5"
      ]
    )

    XCTAssertEqual(plan.sources, [])
    XCTAssertEqual(plan.interval, 2.5)
  }

  @MainActor
  func testSubscriptionPlanIgnoresInvalidIntervalSubscription() {
    let plan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:not-a-number"
      ]
    )

    XCTAssertEqual(plan.sources, [])
    XCTAssertNil(plan.interval)
  }

  @MainActor
  func testSubscriptionPlanIgnoresZeroAndNegativeIntervalSubscriptions() {
    let zeroPlan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:0"
      ]
    )

    let negativePlan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:-5"
      ]
    )

    XCTAssertEqual(zeroPlan.sources, [])
    XCTAssertNil(zeroPlan.interval)

    XCTAssertEqual(negativePlan.sources, [])
    XCTAssertNil(negativePlan.interval)
  }

  @MainActor
  func testSubscriptionPlanIgnoresUnknownSubscriptions() {
    let plan = EventManager.subscriptionPlan(
      for: [
        "unknown_event"
      ]
    )

    XCTAssertEqual(plan.sources, [])
    XCTAssertNil(plan.interval)
  }
}
