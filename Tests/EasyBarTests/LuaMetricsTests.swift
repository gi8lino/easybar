import EasyBarShared
import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarCtl

final class LuaMetricsTests: XCTestCase {
  func testLogBridgeClassifiesStructuredLevelsAndRawStderr() {
    let bridge = LuaLogBridge(
      logger: ProcessLogger(
        label: "lua.metrics.tests",
        minimumLevel: .error,
        outputStream: nil,
        errorStream: nil
      )
    )

    assertStructured(
      bridge.handle("EASYBAR_LUA_LOG\tWARN\tgitlab-inbox\trefresh failed"),
      level: .warn
    )
    assertStructured(
      bridge.handle("EASYBAR_LUA_LOG\tERROR\truntime\tdecode failed"),
      level: .error
    )
    assertStructured(
      bridge.handle("EASYBAR_LUA_LOG\tUNKNOWN\truntime\tfallback"),
      level: .info
    )

    guard case .raw = bridge.handle("lua: runtime.lua:42: unexpected value") else {
      return XCTFail("Expected unstructured stderr to be classified as raw")
    }
  }

  func testMetricsCoordinatorSplitsLuaLogSeveritiesAndRawStderr() async {
    let coordinator = MetricsCoordinator()

    await coordinator.recordLuaSubscriptions(["system_woke", "focus_change"])
    await coordinator.recordLuaStderrLine(.structured(.debug))
    await coordinator.recordLuaStderrLine(.structured(.warn))
    await coordinator.recordLuaStderrLine(.structured(.error))
    await coordinator.recordLuaStderrLine(.raw)

    let runtime = await coordinator.snapshot().runtime

    XCTAssertEqual(runtime.subscribedEvents, ["focus_change", "system_woke"])
    XCTAssertEqual(runtime.stderrLines, 4)
    XCTAssertEqual(runtime.luaLogLines, 3)
    XCTAssertEqual(runtime.luaWarningLines, 1)
    XCTAssertEqual(runtime.luaErrorLines, 1)
    XCTAssertEqual(runtime.luaRawStderrLines, 1)
  }

  func testMetricsRendererUsesExplicitLuaAndWidgetTreeLabels() {
    let text = MetricsRenderer.snapshotText(
      snapshot(
        runtime: runtimeMetrics(
          subscribedEvents: [
            "focus_change",
            "interval_tick:github_inbox_timer:300",
            "system_woke",
          ],
          stderrLines: 10,
          luaLogLines: 8,
          luaWarningLines: 2,
          luaErrorLines: 1,
          luaRawStderrLines: 2
        )
      )
    )

    XCTAssertTrue(text.contains("lua_reads"))
    XCTAssertTrue(text.contains("lua_writes"))
    XCTAssertTrue(text.contains("lua_logs"))
    XCTAssertTrue(text.contains("lua_warn"))
    XCTAssertTrue(text.contains("lua_error"))
    XCTAssertTrue(text.contains("lua_raw_stderr"))
    XCTAssertTrue(text.contains("Subscribed events (3)"))
    XCTAssertTrue(text.contains("- focus_change"))
    XCTAssertTrue(text.contains("- github_inbox_timer (every 5m)"))
    XCTAssertTrue(text.contains("- system_woke"))
    XCTAssertFalse(text.contains("interval_tick:github_inbox_timer:300"))
    XCTAssertTrue(text.contains("Widget trees (top 8)"))
    XCTAssertTrue(text.contains("github_inbox_timer"))
    XCTAssertTrue(text.contains("Events (top 8)"))
    XCTAssertFalse(text.contains("transport/err"))
  }

  func testMetricsRendererFallsBackForLegacyStderrTotals() {
    let text = MetricsRenderer.snapshotText(
      snapshot(runtime: runtimeMetrics(stderrLines: 7))
    )

    XCTAssertTrue(text.contains("lua_stderr"))
    XCTAssertFalse(text.contains("lua_raw_stderr"))
  }

  func testRuntimeMetricsDecodesPayloadWithoutLuaLogBreakdown() throws {
    let encoder = JSONEncoder()
    let encoded = try encoder.encode(runtimeMetrics(stderrLines: 7))
    guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
      return XCTFail("Expected a runtime metrics JSON object")
    }

    object.removeValue(forKey: "luaLogLines")
    object.removeValue(forKey: "luaWarningLines")
    object.removeValue(forKey: "luaErrorLines")
    object.removeValue(forKey: "luaRawStderrLines")
    object.removeValue(forKey: "subscribedEvents")

    let legacyPayload = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(IPC.RuntimeMetrics.self, from: legacyPayload)

    XCTAssertEqual(decoded.stderrLines, 7)
    XCTAssertNil(decoded.subscribedEvents)
    XCTAssertNil(decoded.luaLogLines)
    XCTAssertNil(decoded.luaWarningLines)
    XCTAssertNil(decoded.luaErrorLines)
    XCTAssertNil(decoded.luaRawStderrLines)
  }

  private func assertStructured(
    _ classification: LuaStderrLineClassification,
    level expectedLevel: ProcessLogLevel,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case .structured(let level) = classification else {
      return XCTFail("Expected a structured Lua log line", file: file, line: line)
    }
    XCTAssertEqual(level.rawValue, expectedLevel.rawValue, file: file, line: line)
  }

  private func snapshot(runtime: IPC.RuntimeMetrics) -> IPC.MetricsSnapshot {
    IPC.MetricsSnapshot(
      timestamp: Date(timeIntervalSince1970: 0),
      collectionEnabled: false,
      sampleIntervalSeconds: 1,
      process: IPC.ProcessMetrics(name: "EasyBar", running: true),
      lua: IPC.ProcessMetrics(name: "lua", running: true),
      runtime: runtime,
      agents: [],
      widgets: [
        IPC.WidgetMetrics(
          id: "github_inbox_timer",
          updatesTotal: 1,
          updatesPerSecond: 0,
          lastNodeCount: 1,
          lastUpdatedAt: nil
        )
      ],
      events: []
    )
  }

  private func runtimeMetrics(
    subscribedEvents: [String]? = nil,
    stderrLines: Int,
    luaLogLines: Int? = nil,
    luaWarningLines: Int? = nil,
    luaErrorLines: Int? = nil,
    luaRawStderrLines: Int? = nil
  ) -> IPC.RuntimeMetrics {
    IPC.RuntimeMetrics(
      subscriberCount: 0,
      luaRestartCount: 0,
      luaReady: true,
      subscribedEventCount: subscribedEvents?.count ?? 0,
      subscribedEvents: subscribedEvents,
      totalEvents: 0,
      appEvents: 0,
      widgetEvents: 0,
      eventsPerSecond: 0,
      droppedEvents: 0,
      droppedEventsPerSecond: 0,
      coalescedEvents: 0,
      coalescedEventsPerSecond: 0,
      transportLines: 4,
      stderrLines: stderrLines,
      luaWrites: 5,
      luaLogLines: luaLogLines,
      luaWarningLines: luaWarningLines,
      luaErrorLines: luaErrorLines,
      luaRawStderrLines: luaRawStderrLines,
      treeUpdates: 0,
      treeUpdatesPerSecond: 0,
      decodeErrors: 0,
      luaRuntimeInputOverflows: 0,
      luaEventQueueDepth: 0,
      luaEventQueueOverflows: 0,
      lastTreeRoot: nil,
      lastTreeNodeCount: nil,
      lastTreeAt: nil
    )
  }
}
