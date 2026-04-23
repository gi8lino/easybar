import XCTest

@testable import EasyBar

final class EventHubTests: XCTestCase {
  func testFilteredSubscriptionReceivesMatchingEventOnly() async {
    let hub = EventHub()
    let stream = await hub.subscribe(eventNames: [AppEvent.systemWoke.rawValue])
    let task = Task { await Self.next(from: stream) }

    await hub.emit(.minuteTick)
    await hub.emit(.systemWoke)

    let payload = await task.value
    XCTAssertEqual(payload?.eventName, AppEvent.systemWoke.rawValue)
  }

  func testReplayLatestReplaysMostRecentState() async {
    let hub = EventHub()

    await hub.emit(.secondTick)

    let stream = await hub.subscribe(
      eventNames: [AppEvent.secondTick.rawValue],
      replayLatest: true
    )

    let payload = await Self.next(from: stream)
    XCTAssertEqual(payload?.eventName, AppEvent.secondTick.rawValue)
  }

  func testWidgetEventsRouteOnlyToMatchingTargets() async {
    let hub = EventHub()

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
      await Self.next(from: nonMatchingStream, timeoutNanoseconds: 100_000_000)
    }

    await hub.emitWidgetEvent(
      .sliderPreview,
      widgetID: "builtin_volume",
      targetWidgetID: "volume_slider",
      value: 0.5
    )

    let matchingPayload = await matchingTask.value
    let nonMatchingPayload = await nonMatchingTask.value

    XCTAssertEqual(matchingPayload?.targetWidgetID, "volume_slider")
    XCTAssertNil(nonMatchingPayload)
  }

  private static func next(
    from stream: AsyncStream<EasyBarEventPayload>,
    timeoutNanoseconds: UInt64 = 1_000_000_000
  ) async -> EasyBarEventPayload? {
    await withTaskGroup(of: EasyBarEventPayload?.self) { group in
      group.addTask {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
      }

      group.addTask {
        try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        return nil
      }

      let value = await group.next() ?? nil
      group.cancelAll()
      return value
    }
  }
}
