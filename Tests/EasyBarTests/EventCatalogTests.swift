import XCTest

@testable import EasyBar

final class EventCatalogTests: XCTestCase {
  /// Handles test lua definitions match swift catalog.
  func testLuaDefinitionsMatchSwiftCatalog() {
    XCTAssertEqual(EventCatalog.currentLuaDefinitionWarnings(), [])
  }

  /// Handles test lua token names include widget events and forced event.
  func testLuaTokenNamesIncludeWidgetEventsAndForcedEvent() {
    XCTAssertTrue(EventCatalog.luaTokenEventNames.contains(EventCatalog.forcedEventName))
    XCTAssertTrue(EventCatalog.luaTokenEventNames.contains(WidgetEvent.mouseClicked.rawValue))
    XCTAssertTrue(EventCatalog.luaTokenEventNames.contains(WidgetEvent.sliderChanged.rawValue))
  }

  /// Handles test lua token names exclude internal app events.
  func testLuaTokenNamesExcludeInternalAppEvents() {
    XCTAssertFalse(EventCatalog.luaTokenEventNames.contains(AppEvent.manualRefresh.rawValue))
    XCTAssertFalse(EventCatalog.luaTokenEventNames.contains(AppEvent.intervalTick.rawValue))
  }

  /// Handles test lua driver names include forced event and external app events.
  func testLuaDriverNamesIncludeForcedEventAndExternalAppEvents() {
    XCTAssertTrue(EventCatalog.luaDriverEventNames.contains(EventCatalog.forcedEventName))
    XCTAssertTrue(EventCatalog.luaDriverEventNames.contains(AppEvent.systemWoke.rawValue))
    XCTAssertTrue(EventCatalog.luaDriverEventNames.contains(AppEvent.secondTick.rawValue))
  }

  /// Handles test lua driver names exclude widget events and internal app events.
  func testLuaDriverNamesExcludeWidgetEventsAndInternalAppEvents() {
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(WidgetEvent.mouseClicked.rawValue))
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(WidgetEvent.sliderChanged.rawValue))
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(AppEvent.manualRefresh.rawValue))
    XCTAssertFalse(EventCatalog.luaDriverEventNames.contains(AppEvent.intervalTick.rawValue))
  }

  @MainActor
  /// Handles test subscription plan includes interval and grouped sources.
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
  /// Handles test subscription plan returns empty plan for no subscriptions.
  func testSubscriptionPlanReturnsEmptyPlanForNoSubscriptions() {
    let plan = EventManager.subscriptionPlan(for: [])

    XCTAssertEqual(plan.sources, [])
    XCTAssertNil(plan.interval)
  }

  @MainActor
  /// Handles test subscription plan includes system sources.
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
  /// Handles test subscription plan groups power events into single power source.
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
  /// Handles test subscription plan groups volume events into single volume source.
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
  /// Handles test subscription plan includes timer sources.
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
  /// Handles test subscription plan parses positive interval subscription.
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
  /// Handles test subscription plan ignores invalid interval subscription.
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
  /// Handles test subscription plan ignores zero and negative interval subscriptions.
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
  /// Handles test subscription plan ignores unknown subscriptions.
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
