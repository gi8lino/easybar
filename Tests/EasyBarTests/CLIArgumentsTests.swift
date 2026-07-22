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

  func testInboxSendParsesStructuredMessage() throws {
    let parsed = try parseArguments([
      "easybar", "inbox", "send",
      "--source", "backup",
      "--id", "minio-nightly",
      "--severity", "error",
      "--title", "Backup failed",
      "--message", "The nightly backup failed.",
      "--group", "backup:minio",
      "--url", "https://grafana.example.com/backup-logs",
    ])

    guard case .inbox(.send(let item)) = parsed.action else {
      return XCTFail("Expected inbox send action")
    }
    XCTAssertEqual(item.source, "backup")
    XCTAssertEqual(item.id, "minio-nightly")
    XCTAssertEqual(item.severity, .error)
    XCTAssertEqual(item.title, "Backup failed")
    XCTAssertEqual(item.message, "The nightly backup failed.")
    XCTAssertEqual(item.group, "backup:minio")
    XCTAssertEqual(item.url, "https://grafana.example.com/backup-logs")
    XCTAssertTrue(item.unread)
  }

  func testInboxReadAndMutationParsing() throws {
    let read = try parseArguments([
      "easybar", "inbox", "read", "--source", "backup", "--unread", "--json",
    ])
    XCTAssertEqual(
      read.action,
      .inbox(.read(source: "backup", unreadOnly: true, json: true))
    )

    let markRead = try parseArguments([
      "easybar", "inbox", "mark-read", "--source", "backup", "--id", "nightly",
    ])
    XCTAssertEqual(
      markRead.action,
      .inbox(.markRead(source: "backup", id: "nightly"))
    )

    let remove = try parseArguments([
      "easybar", "inbox", "remove", "--source", "backup", "--id", "nightly",
    ])
    XCTAssertEqual(remove.action, .inbox(.remove(source: "backup", id: "nightly")))
  }

  func testInboxDestructiveCommandsRequireScope() {
    XCTAssertThrowsError(try parseArguments(["easybar", "inbox", "dismiss"]))
    XCTAssertThrowsError(try parseArguments(["easybar", "inbox", "clear"]))
    XCTAssertThrowsError(
      try parseArguments(["easybar", "inbox", "remove", "--source", "backup"])
    )
    XCTAssertNoThrow(try parseArguments(["easybar", "inbox", "clear", "--all"]))
  }
}
