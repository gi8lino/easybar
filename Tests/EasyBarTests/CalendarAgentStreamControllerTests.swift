import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

@MainActor
final class CalendarAgentStreamControllerTests: XCTestCase {
  func testInvalidRequestRetainsSnapshotAndWaitsForChangedRequest() async throws {
    let logger = ProcessLogger(
      label: "calendar.stream.tests",
      minimumLevel: .error,
      outputStream: nil,
      errorStream: nil
    )
    let temporaryDirectory = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("eb-calendar-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let socketPath = temporaryDirectory.appendingPathComponent("agent.sock").path
    let request = LockedState(Self.makeRequest(marker: "valid"))
    let requestCount = LockedState(0)
    let appliedSnapshots = LockedState(0)
    let clearedSnapshots = LockedState(0)

    let server = LineSocketServerTransport<
      Void, CalendarAgentRequest, CalendarAgentMessage
    >(
      socketPath: socketPath,
      serverLabel: "calendar stream tests",
      logger: logger
    )
    XCTAssertTrue(
      server.start { fd, request in
        requestCount.withLock { $0 += 1 }

        if request.query?.emptyText == "invalid" {
          _ = server.send(
            CalendarAgentMessage(
              kind: .error,
              errorCode: .invalidRequest,
              message: "invalid request"
            ),
            to: fd
          )
          return .close
        }

        server.addSubscriber((), for: fd)
        _ = server.send(
          CalendarAgentMessage(kind: .snapshot, snapshot: Self.makeSnapshot()),
          to: fd
        )
        return .keepOpen
      }
    )
    defer { server.stop() }

    let eventHub = EventHub(logger: logger, enqueueLuaEvent: { _ in })
    let eventRelay = CalendarAgentEventRelay(logger: logger, eventHub: eventHub)
    let controller = CalendarAgentStreamController(
      label: "calendar stream test client",
      socketPath: { socketPath },
      makeRequest: { request.withLock { $0 } },
      applySnapshot: { _ in appliedSnapshots.withLock { $0 += 1 } },
      clearState: { clearedSnapshots.withLock { $0 += 1 } },
      eventRelay: eventRelay,
      logger: logger
    )
    controller.start(enabled: true)
    defer { controller.stop() }

    try await waitUntil("initial snapshot") {
      appliedSnapshots.withLock { $0 == 1 }
    }

    request.withLock { $0 = Self.makeRequest(marker: "invalid") }
    controller.refresh()

    try await waitUntil("invalid request disconnect") {
      requestCount.withLock { $0 == 2 } && !controller.isConnected
    }
    XCTAssertEqual(clearedSnapshots.withLock { $0 }, 0)

    controller.refresh()
    try await Task.sleep(nanoseconds: 150_000_000)
    XCTAssertEqual(requestCount.withLock { $0 }, 2)
    XCTAssertEqual(clearedSnapshots.withLock { $0 }, 0)

    request.withLock { $0 = Self.makeRequest(marker: "changed") }
    controller.refresh()

    try await waitUntil("changed request snapshot") {
      requestCount.withLock { $0 == 3 } && appliedSnapshots.withLock { $0 == 2 }
    }
    XCTAssertEqual(clearedSnapshots.withLock { $0 }, 0)
  }

  private static func makeRequest(marker: String) -> CalendarAgentRequest {
    let start = Date(timeIntervalSince1970: 1_700_000_000)
    return .subscribe(
      CalendarAgentQuery(
        startDate: start,
        endDate: start.addingTimeInterval(86_400),
        showBirthdays: false,
        emptyText: marker,
        birthdaysTitle: "Birthdays",
        birthdaysDateFormat: "dd.MM.yyyy",
        birthdaysShowAge: false
      )
    )
  }

  nonisolated private static func makeSnapshot() -> CalendarAgentSnapshot {
    CalendarAgentSnapshot(
      accessGranted: true,
      permissionState: "authorized",
      generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
      writableCalendars: [],
      events: [],
      sections: []
    )
  }

  private func waitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping @MainActor () -> Bool
  ) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
      if condition() { return }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    XCTFail("Timed out waiting for \(description)")
  }
}
