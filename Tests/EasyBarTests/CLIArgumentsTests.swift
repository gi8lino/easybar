import XCTest

@testable import EasyBarCtl

final class CLIArgumentsTests: XCTestCase {
  func testLogsDefaultsToRecentHistoryAndFollowing() throws {
    let parsed = try parseArguments(["easybar", "logs"])

    XCTAssertEqual(parsed.action, .logs)
    XCTAssertEqual(parsed.logOptions.historyLimit, 100)
    XCTAssertTrue(parsed.logOptions.follow)
    XCTAssertFalse(parsed.logOptions.json)
  }

  func testLogsParsesComposableFilters() throws {
    let parsed = try parseArguments([
      "easybar",
      "logs",
      "--widget",
      "tailscale",
      "--runtime=lua",
      "--level",
      "debug",
      "--since",
      "30m",
      "--request-id",
      "lua-19",
      "--lines",
      "25",
      "--no-follow",
      "--json",
    ])

    XCTAssertEqual(parsed.logOptions.widget, "tailscale")
    XCTAssertEqual(parsed.logOptions.runtime, .lua)
    XCTAssertEqual(parsed.logOptions.minimumLevel, .debug)
    XCTAssertEqual(parsed.logOptions.since, "30m")
    XCTAssertEqual(parsed.logOptions.requestID, "lua-19")
    XCTAssertEqual(parsed.logOptions.historyLimit, 25)
    XCTAssertFalse(parsed.logOptions.follow)
    XCTAssertTrue(parsed.logOptions.json)
  }

  func testSinceAndRequestIDDefaultToAllRetainedHistory() throws {
    let since = try parseArguments(["easybar", "logs", "--since", "1h"])
    let request = try parseArguments(["easybar", "logs", "--request-id", "lua-19"])

    XCTAssertNil(since.logOptions.historyLimit)
    XCTAssertNil(request.logOptions.historyLimit)
  }

  func testLogOptionsRequireLogsCommand() {
    XCTAssertThrowsError(try parseArguments(["easybar", "--refresh", "--since", "1h"]))
    XCTAssertThrowsError(try parseArguments(["easybar", "logs", "--all", "--lines", "10"]))
  }
}
