import EasyBarShared
import XCTest

@testable import EasyBar

final class EventHubTests: XCTestCase {
  /// Creates hub.
  private static func makeHub() -> EventHub {
    EventHub(
      logger: ProcessLogger(
        label: "eventhub.test",
        minimumLevel: .error
      ),
      luaEventSink: NoopEventSink()
    )
  }

  private final class NoopEventSink: EventPayloadSink {
    /// Handles enqueue.
    func enqueue(_ payload: EasyBarEventPayload) {}
  }

  /// Handles test filtered subscription receives matching event only.
  func testFilteredSubscriptionReceivesMatchingEventOnly() async {
    let hub = Self.makeHub()
    let stream = await hub.subscribe(eventNames: [AppEvent.systemWoke.rawValue])
    let task = Task { await Self.next(from: stream) }

    await hub.emit(.minuteTick)
    await hub.emit(.systemWoke)

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, AppEvent.systemWoke.rawValue)
  }

  /// Handles test unfiltered subscription receives app event.
  func testUnfilteredSubscriptionReceivesAppEvent() async {
    let hub = Self.makeHub()
    let stream = await hub.subscribe()
    let task = Task { await Self.next(from: stream) }

    await hub.emit(.minuteTick)

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, AppEvent.minuteTick.rawValue)
  }

  /// Handles test empty event filter behaves like unfiltered subscription.
  func testEmptyEventFilterBehavesLikeUnfilteredSubscription() async {
    let hub = Self.makeHub()
    let stream = await hub.subscribe(eventNames: Set<String>())
    let task = Task { await Self.next(from: stream) }

    await hub.emit(.secondTick)

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, AppEvent.secondTick.rawValue)
  }

  /// Handles test replay latest replays most recent replayable state.
  func testReplayLatestReplaysMostRecentReplayableState() async {
    let hub = Self.makeHub()

    await hub.emit(.secondTick)

    let stream = await hub.subscribe(
      eventNames: [AppEvent.secondTick.rawValue],
      replayLatest: true
    )

    let payload = await Self.next(from: stream)

    XCTAssertEqual(payload?.eventName, AppEvent.secondTick.rawValue)
  }

  /// Handles test replay latest uses most recent payload for replayable event.
  func testReplayLatestUsesMostRecentPayloadForReplayableEvent() async {
    let hub = Self.makeHub()

    await hub.emit(.networkChange, primaryInterfaceIsTunnel: false)
    await hub.emit(.networkChange, primaryInterfaceIsTunnel: true)

    let stream = await hub.subscribe(
      eventNames: [AppEvent.networkChange.rawValue],
      replayLatest: true
    )

    let payload = await Self.next(from: stream)

    XCTAssertEqual(payload?.eventName, AppEvent.networkChange.rawValue)
    XCTAssertEqual(payload?.primaryInterfaceIsTunnel, true)
  }

  /// Handles test replay latest respects event filter.
  func testReplayLatestRespectsEventFilter() async {
    let hub = Self.makeHub()

    await hub.emit(.minuteTick)
    await hub.emit(.secondTick)

    let stream = await hub.subscribe(
      eventNames: [AppEvent.secondTick.rawValue],
      replayLatest: true
    )

    let payload = await Self.next(from: stream)

    XCTAssertEqual(payload?.eventName, AppEvent.secondTick.rawValue)
  }

  /// Handles test replay latest without event filter replays all cached events in stable order.
  func testReplayLatestWithoutEventFilterReplaysAllCachedEventsInStableOrder() async {
    let hub = Self.makeHub()

    await hub.emit(.secondTick)
    await hub.emit(.networkChange, primaryInterfaceIsTunnel: true)

    let stream = await hub.subscribe(replayLatest: true)

    let payloads = await Self.collect(
      from: stream,
      count: 2,
      timeoutNanoseconds: 1_000_000_000
    )

    XCTAssertEqual(
      payloads.map(\.eventName),
      [
        AppEvent.networkChange.rawValue,
        AppEvent.secondTick.rawValue,
      ]
    )
    XCTAssertEqual(payloads.first?.primaryInterfaceIsTunnel, true)
    XCTAssertNil(payloads.last?.primaryInterfaceIsTunnel)
  }

  /// Handles test replay latest does not emit when no cached payload exists.
  func testReplayLatestDoesNotEmitWhenNoCachedPayloadExists() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [AppEvent.secondTick.rawValue],
      replayLatest: true
    )

    let payload = await Self.next(
      from: stream,
      timeoutNanoseconds: 100_000_000
    )

    XCTAssertNil(payload)
  }

  /// Handles test replay latest does not replay non replayable widget event.
  func testReplayLatestDoesNotReplayNonReplayableWidgetEvent() async {
    let hub = Self.makeHub()

    await hub.emitWidgetEvent(
      .mouseClicked,
      widgetID: "clock",
      button: .left
    )

    let stream = await hub.subscribe(
      eventNames: [WidgetEvent.mouseClicked.rawValue],
      replayLatest: true
    )

    let payload = await Self.next(
      from: stream,
      timeoutNanoseconds: 100_000_000
    )

    XCTAssertNil(payload)
  }

  /// Handles test emit replayable state emits requested replayable events in stable order.
  func testEmitReplayableStateEmitsRequestedReplayableEventsInStableOrder() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [
        AppEvent.minuteTick.rawValue,
        AppEvent.secondTick.rawValue,
      ]
    )

    let task = Task {
      await Self.collect(
        from: stream,
        count: 2,
        timeoutNanoseconds: 1_000_000_000
      )
    }

    await hub.emitReplayableState(
      for: [
        AppEvent.minuteTick.rawValue,
        AppEvent.secondTick.rawValue,
      ]
    )

    let payloads = await task.value

    XCTAssertEqual(
      payloads.map(\.eventName),
      [
        AppEvent.minuteTick.rawValue,
        AppEvent.secondTick.rawValue,
      ]
    )
  }

  /// Handles test emit replayable state ignores unknown event names.
  func testEmitReplayableStateIgnoresUnknownEventNames() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(eventNames: ["unknown_event"])
    let task = Task {
      await Self.next(
        from: stream,
        timeoutNanoseconds: 100_000_000
      )
    }

    await hub.emitReplayableState(for: ["unknown_event"])

    let payload = await task.value

    XCTAssertNil(payload)
  }

  /// Handles test widget events route only to matching target widget ids.
  func testWidgetEventsRouteOnlyToMatchingTargetWidgetIDs() async {
    let hub = Self.makeHub()

    let matchingStream = await hub.subscribe(
      eventNames: [WidgetEvent.sliderPreview.rawValue],
      widgetTargetIDs: ["volume_slider"]
    )

    let nonMatchingStream = await hub.subscribe(
      eventNames: [WidgetEvent.sliderPreview.rawValue],
      widgetTargetIDs: ["other_widget"]
    )

    let matchingTask = Task { await Self.next(from: matchingStream) }
    let nonMatchingTask = Task {
      await Self.next(
        from: nonMatchingStream,
        timeoutNanoseconds: 100_000_000
      )
    }

    await hub.emitWidgetEvent(
      .sliderPreview,
      widgetID: "builtin_volume",
      targetWidgetID: "volume_slider",
      value: 0.5
    )

    let matchingPayload = await matchingTask.value
    let nonMatchingPayload = await nonMatchingTask.value

    XCTAssertEqual(matchingPayload?.eventName, WidgetEvent.sliderPreview.rawValue)
    XCTAssertEqual(matchingPayload?.targetWidgetID, "volume_slider")
    XCTAssertEqual(matchingPayload?.value, 0.5)
    XCTAssertNil(nonMatchingPayload)
  }

  /// Handles test widget events route to matching source widget id.
  func testWidgetEventsRouteToMatchingSourceWidgetID() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [WidgetEvent.mouseClicked.rawValue],
      widgetTargetIDs: ["clock"]
    )

    let task = Task { await Self.next(from: stream) }

    await hub.emitWidgetEvent(
      .mouseClicked,
      widgetID: "clock",
      button: .left
    )

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, WidgetEvent.mouseClicked.rawValue)
    XCTAssertEqual(payload?.widgetID, "clock")
    XCTAssertEqual(payload?.button, .left)
  }

  /// Handles test widget subscription without target filter receives matching widget event.
  func testWidgetSubscriptionWithoutTargetFilterReceivesMatchingWidgetEvent() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [WidgetEvent.mouseScrolled.rawValue]
    )

    let task = Task { await Self.next(from: stream) }

    await hub.emitWidgetEvent(
      .mouseScrolled,
      widgetID: "calendar",
      direction: .down,
      deltaX: 0,
      deltaY: -8
    )

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, WidgetEvent.mouseScrolled.rawValue)
    XCTAssertEqual(payload?.widgetID, "calendar")
    XCTAssertEqual(payload?.direction, .down)
    XCTAssertEqual(payload?.deltaX, 0)
    XCTAssertEqual(payload?.deltaY, -8)
  }

  /// Handles test empty widget target filter behaves like unfiltered widget subscription.
  func testEmptyWidgetTargetFilterBehavesLikeUnfilteredWidgetSubscription() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [WidgetEvent.sliderPreview.rawValue],
      widgetTargetIDs: Set<String>()
    )

    let task = Task { await Self.next(from: stream) }

    await hub.emitWidgetEvent(
      .sliderPreview,
      widgetID: "builtin_volume",
      targetWidgetID: "volume_slider",
      value: 0.5
    )

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, WidgetEvent.sliderPreview.rawValue)
    XCTAssertEqual(payload?.targetWidgetID, "volume_slider")
    XCTAssertEqual(payload?.value, 0.5)
  }

  /// Handles test widget event filter still requires matching event name.
  func testWidgetEventFilterStillRequiresMatchingEventName() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [WidgetEvent.sliderChanged.rawValue],
      widgetTargetIDs: ["volume_slider"]
    )

    let task = Task {
      await Self.next(
        from: stream,
        timeoutNanoseconds: 100_000_000
      )
    }

    await hub.emitWidgetEvent(
      .sliderPreview,
      widgetID: "builtin_volume",
      targetWidgetID: "volume_slider",
      value: 0.5
    )

    let payload = await task.value

    XCTAssertNil(payload)
  }

  /// Handles test app events ignore widget target filter when event name matches.
  func testAppEventsIgnoreWidgetTargetFilterWhenEventNameMatches() async {
    let hub = Self.makeHub()

    let stream = await hub.subscribe(
      eventNames: [AppEvent.systemWoke.rawValue],
      widgetTargetIDs: ["some_widget"]
    )

    let task = Task { await Self.next(from: stream) }

    await hub.emit(.systemWoke)

    let payload = await task.value

    XCTAssertEqual(payload?.eventName, AppEvent.systemWoke.rawValue)
  }

  /// Handles test app payload dictionary includes nested context.
  func testAppPayloadDictionaryIncludesNestedContext() {
    let payload = EasyBarEventPayload.app(
      .networkChange,
      appName: "Finder",
      interfaceName: "utun4",
      charging: true,
      muted: false,
      primaryInterfaceIsTunnel: true
    )

    let dictionary = payload.toDictionary()
    let network = dictionary["network"] as? [String: Any]
    let power = dictionary["power"] as? [String: Any]
    let audio = dictionary["audio"] as? [String: Any]

    XCTAssertEqual(dictionary["name"] as? String, AppEvent.networkChange.rawValue)
    XCTAssertEqual(dictionary["app_name"] as? String, "Finder")

    XCTAssertEqual(network?["interface_name"] as? String, "utun4")
    XCTAssertEqual(network?["primary_interface_is_tunnel"] as? Bool, true)

    XCTAssertEqual(power?["charging"] as? Bool, true)
    XCTAssertEqual(audio?["muted"] as? Bool, false)

    XCTAssertNil(dictionary["widget_id"])
    XCTAssertNil(dictionary["target_widget_id"])
  }

  /// Handles test widget payload dictionary includes interaction context.
  func testWidgetPayloadDictionaryIncludesInteractionContext() {
    let payload = EasyBarEventPayload.widget(
      .mouseScrolled,
      widgetID: "calendar",
      targetWidgetID: "calendar_popup",
      button: .middle,
      direction: .down,
      value: 0.75,
      deltaX: 1.5,
      deltaY: -4.25
    )

    let dictionary = payload.toDictionary()
    let audio = dictionary["audio"] as? [String: Any]

    XCTAssertEqual(dictionary["name"] as? String, WidgetEvent.mouseScrolled.rawValue)
    XCTAssertEqual(dictionary["widget_id"] as? String, "calendar")
    XCTAssertEqual(dictionary["target_widget_id"] as? String, "calendar_popup")
    XCTAssertEqual(dictionary["button"] as? String, MouseButton.middle.rawValue)
    XCTAssertEqual(dictionary["direction"] as? String, ScrollDirection.down.rawValue)
    XCTAssertEqual(dictionary["value"] as? Double, 0.75)
    XCTAssertEqual(dictionary["delta_x"] as? Double, 1.5)
    XCTAssertEqual(dictionary["delta_y"] as? Double, -4.25)

    XCTAssertEqual(audio?["value"] as? Double, 0.75)
  }

  /// Handles test event replay catalog identifies replayable events.
  func testEventReplayCatalogIdentifiesReplayableEvents() {
    XCTAssertTrue(EventReplayCatalog.isReplayable(AppEvent.secondTick.rawValue))
    XCTAssertTrue(EventReplayCatalog.isReplayable(AppEvent.networkChange.rawValue))
    XCTAssertFalse(EventReplayCatalog.isReplayable(WidgetEvent.mouseClicked.rawValue))
    XCTAssertFalse(EventReplayCatalog.isReplayable("unknown_event"))
  }

  /// Handles test event delivery policy routes only widget events directly to widgets.
  func testEventDeliveryPolicyRoutesOnlyWidgetEventsDirectlyToWidgets() {
    XCTAssertTrue(
      EventDeliveryPolicy.routesDirectlyToWidgets(
        WidgetEvent.mouseClicked.rawValue
      )
    )

    XCTAssertTrue(
      EventDeliveryPolicy.routesDirectlyToWidgets(
        WidgetEvent.sliderPreview.rawValue
      )
    )

    XCTAssertFalse(
      EventDeliveryPolicy.routesDirectlyToWidgets(
        AppEvent.systemWoke.rawValue
      )
    )
  }

  /// Handles test event delivery policy classifies coalescing events.
  func testEventDeliveryPolicyClassifiesCoalescingEvents() {
    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(AppEvent.secondTick.rawValue),
      .coalescing
    )

    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(AppEvent.intervalTick.rawValue),
      .coalescing
    )

    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(WidgetEvent.mouseScrolled.rawValue),
      .coalescing
    )

    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(WidgetEvent.sliderPreview.rawValue),
      .coalescing
    )
  }

  /// Handles test event delivery policy classifies reliable events.
  func testEventDeliveryPolicyClassifiesReliableEvents() {
    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(AppEvent.systemWoke.rawValue),
      .reliable
    )

    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(AppEvent.powerSourceChange.rawValue),
      .reliable
    )

    XCTAssertEqual(
      EventDeliveryPolicy.forEventName(WidgetEvent.mouseClicked.rawValue),
      .reliable
    )

    XCTAssertEqual(
      EventDeliveryPolicy.forEventName("unknown_event"),
      .reliable
    )
  }

  /// Handles test default buffering policy uses smallest buffer for coalescing only subscriptions.
  func testDefaultBufferingPolicyUsesSmallestBufferForCoalescingOnlySubscriptions() {
    let policy = EventDeliveryPolicy.defaultBufferingPolicy(
      for: [
        AppEvent.secondTick.rawValue,
        WidgetEvent.sliderPreview.rawValue,
      ]
    )

    XCTAssertEqual(bufferSize(for: policy), 1)
  }

  /// Handles test default buffering policy uses medium buffer for mixed subscriptions.
  func testDefaultBufferingPolicyUsesMediumBufferForMixedSubscriptions() {
    let policy = EventDeliveryPolicy.defaultBufferingPolicy(
      for: [
        AppEvent.secondTick.rawValue,
        AppEvent.systemWoke.rawValue,
      ]
    )

    XCTAssertEqual(bufferSize(for: policy), 8)
  }

  /// Handles test default buffering policy uses largest buffer for reliable only or unfiltered subscriptions.
  func testDefaultBufferingPolicyUsesLargestBufferForReliableOnlyOrUnfilteredSubscriptions() {
    let reliableOnlyPolicy = EventDeliveryPolicy.defaultBufferingPolicy(
      for: [
        AppEvent.systemWoke.rawValue,
        AppEvent.powerSourceChange.rawValue,
      ]
    )
    let unfilteredPolicy = EventDeliveryPolicy.defaultBufferingPolicy(for: nil)

    XCTAssertEqual(bufferSize(for: reliableOnlyPolicy), 32)
    XCTAssertEqual(bufferSize(for: unfilteredPolicy), 32)
  }

  /// Handles next.
  private static func next(
    from stream: AsyncStream<EasyBarEventPayload>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
  ) async -> EasyBarEventPayload? {
    await collect(
      from: stream,
      count: 1,
      timeoutNanoseconds: timeoutNanoseconds
    ).first
  }

  /// Handles collect.
  private static func collect(
    from stream: AsyncStream<EasyBarEventPayload>,
    count: Int,
    timeoutNanoseconds: UInt64
  ) async -> [EasyBarEventPayload] {
    await withTaskGroup(of: [EasyBarEventPayload].self) { group in
      group.addTask {
        var iterator = stream.makeAsyncIterator()
        var payloads: [EasyBarEventPayload] = []
        payloads.reserveCapacity(count)

        while payloads.count < count {
          guard let payload = await iterator.next() else { break }

          payloads.append(payload)
        }

        return payloads
      }

      group.addTask {
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        return []
      }

      let payloads = await group.next() ?? []
      group.cancelAll()
      return payloads
    }
  }

  /// Handles buffer size.
  private func bufferSize(
    for policy: AsyncStream<EasyBarEventPayload>.Continuation.BufferingPolicy
  ) -> Int? {
    switch policy {
    case .unbounded:
      return nil
    case .bufferingOldest(let count), .bufferingNewest(let count):
      return count
    @unknown default:
      XCTFail("Unhandled buffering policy")
      return nil
    }
  }
}
