import EasyBarShared
import Foundation
import XCTest

final class IPCInboxTests: XCTestCase {
  func testInboxSendRequestRoundTrips() throws {
    let item = IPC.InboxItem(
      source: "backup",
      id: "nightly",
      title: "Backup failed",
      message: "Three attempts failed.",
      severity: .error,
      group: "backup:minio",
      url: "https://grafana.example.com/backup-logs",
      timestamp: 123,
      unread: true
    )
    let request = IPC.Request.makeInbox(.init(operation: .send, item: item))

    let data = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(IPC.Request.self, from: data)

    guard case .inbox(let inbox) = decoded else {
      return XCTFail("Expected inbox request")
    }
    XCTAssertEqual(inbox.operation, .send)
    XCTAssertEqual(inbox.item, item)
    XCTAssertEqual(decoded.command, .inboxSend)
  }

  func testInboxResponseRoundTrips() throws {
    let item = IPC.InboxItem(
      source: "backup",
      id: "nightly",
      title: "Backup failed",
      severity: .error,
      timestamp: 123
    )
    let message = IPC.Message.inbox([item])

    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(IPC.Message.self, from: data)

    guard case .inbox(let items) = decoded else {
      return XCTFail("Expected inbox response")
    }
    XCTAssertEqual(items, [item])
  }

  func testInboxCommandMustMatchPayloadOperation() {
    let data = Data(
      #"{"command":"inbox_send","inbox":{"operation":"read","unread_only":false}}"#.utf8
    )

    XCTAssertThrowsError(try JSONDecoder().decode(IPC.Request.self, from: data))
  }

  func testInboxRemoveRequestRoundTrips() throws {
    let request = IPC.Request.makeInbox(
      .init(operation: .remove, source: "backup", id: "nightly")
    )
    let decoded = try JSONDecoder().decode(
      IPC.Request.self,
      from: JSONEncoder().encode(request)
    )

    XCTAssertEqual(decoded.command, .inboxRemove)
  }
}
