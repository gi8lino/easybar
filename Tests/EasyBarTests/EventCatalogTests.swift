import XCTest

@testable import EasyBarApp

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
        "interval_tick:brew:5",
      ]
    )

    XCTAssertEqual(plan.intervalSchedules, [WidgetIntervalSchedule(widgetID: "brew", interval: 5)])
    XCTAssertTrue(plan.sources.contains("powerSource"))
    XCTAssertTrue(plan.sources.contains("secondTick"))
    XCTAssertFalse(plan.sources.contains("minuteTick"))
  }

  @MainActor
  /// Handles test subscription plan returns empty plan for no subscriptions.
  func testSubscriptionPlanReturnsEmptyPlanForNoSubscriptions() {
    let plan = EventManager.subscriptionPlan(for: [])

    XCTAssertEqual(plan.sources, [])
    XCTAssertEqual(plan.intervalSchedules, [])
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
    XCTAssertEqual(plan.intervalSchedules, [])
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
    XCTAssertEqual(plan.intervalSchedules, [])
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
    XCTAssertEqual(plan.intervalSchedules, [])
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
    XCTAssertEqual(plan.intervalSchedules, [])
  }

  @MainActor
  /// Handles test subscription plan parses positive interval subscription.
  func testSubscriptionPlanParsesPositiveIntervalSubscription() {
    let plan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:brew:2.5"
      ]
    )

    XCTAssertEqual(plan.sources, [])
    XCTAssertEqual(plan.intervalSchedules, [WidgetIntervalSchedule(widgetID: "brew", interval: 2.5)])
  }

  @MainActor
  /// Handles test subscription plan keeps every valid widget interval subscription.
  func testSubscriptionPlanKeepsEveryValidWidgetIntervalSubscription() {
    let plan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:brew:10",
        "interval_tick:clock:2.5",
        "interval_tick:calendar:5",
      ]
    )

    XCTAssertEqual(plan.sources, [])
    XCTAssertEqual(
      plan.intervalSchedules,
      [
        WidgetIntervalSchedule(widgetID: "brew", interval: 10),
        WidgetIntervalSchedule(widgetID: "clock", interval: 2.5),
        WidgetIntervalSchedule(widgetID: "calendar", interval: 5),
      ]
    )
  }

  @MainActor
  /// Handles test subscription plan ignores invalid interval subscription.
  func testSubscriptionPlanIgnoresInvalidIntervalSubscription() {
    let plan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:brew:not-a-number"
      ]
    )

    XCTAssertEqual(plan.sources, [])
    XCTAssertEqual(plan.intervalSchedules, [])
  }

  @MainActor
  /// Handles test subscription plan ignores zero and negative interval subscriptions.
  func testSubscriptionPlanIgnoresZeroAndNegativeIntervalSubscriptions() {
    let zeroPlan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:brew:0"
      ]
    )

    let negativePlan = EventManager.subscriptionPlan(
      for: [
        "interval_tick:brew:-5"
      ]
    )

    XCTAssertEqual(zeroPlan.sources, [])
    XCTAssertEqual(zeroPlan.intervalSchedules, [])

    XCTAssertEqual(negativePlan.sources, [])
    XCTAssertEqual(negativePlan.intervalSchedules, [])
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
    XCTAssertEqual(plan.intervalSchedules, [])
  }
}
