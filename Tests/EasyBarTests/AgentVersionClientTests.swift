import EasyBarShared
import Foundation
import XCTest

final class AgentVersionClientTests: XCTestCase {
  func testQueriesCalendarAgentVersion() throws {
    let fixture = try SocketFixture(name: "calendar-version")
    defer { fixture.cleanup() }
    let server = LineSocketServerTransport<Void, CalendarAgentRequest, CalendarAgentMessage>(
      socketPath: fixture.socketPath,
      serverLabel: "calendar version tests",
      logger: fixture.logger
    )
    XCTAssertTrue(
      server.start { fd, request in
        XCTAssertEqual(request.command, .version)
        _ = server.send(
          CalendarAgentMessage(
            kind: .version,
            version: CalendarAgentVersion(appVersion: "1.2.3", protocolVersion: "4")
          ),
          to: fd
        )
        return .close
      }
    )
    defer { server.stop() }

    let version = try AgentVersionClient.calendarAgentVersion(socketPath: fixture.socketPath)

    XCTAssertEqual(version, CalendarAgentVersion(appVersion: "1.2.3", protocolVersion: "4"))
  }

  func testQueriesNetworkAgentVersion() throws {
    let fixture = try SocketFixture(name: "network-version")
    defer { fixture.cleanup() }
    let server = LineSocketServerTransport<Void, NetworkAgentRequest, NetworkAgentMessage>(
      socketPath: fixture.socketPath,
      serverLabel: "network version tests",
      logger: fixture.logger
    )
    XCTAssertTrue(
      server.start { fd, request in
        XCTAssertEqual(request.command, .version)
        _ = server.send(
          NetworkAgentMessage(
            kind: .version,
            version: NetworkAgentVersion(appVersion: "2.3.4", protocolVersion: "5")
          ),
          to: fd
        )
        return .close
      }
    )
    defer { server.stop() }

    let version = try AgentVersionClient.networkAgentVersion(socketPath: fixture.socketPath)

    XCTAssertEqual(version, NetworkAgentVersion(appVersion: "2.3.4", protocolVersion: "5"))
  }
}

private struct SocketFixture {
  let directory: URL
  let socketPath: String
  let logger = ProcessLogger(
    label: "agent.version.tests",
    minimumLevel: .error,
    outputStream: nil,
    errorStream: nil
  )

  init(name: String) throws {
    directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("easybar-\(name)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    socketPath = directory.appendingPathComponent("agent.sock").path
  }

  func cleanup() {
    try? FileManager.default.removeItem(at: directory)
  }
}
