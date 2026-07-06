import EasyBarShared
import XCTest

final class AgentSocketClientTests: XCTestCase {
  private struct TestRequest: Codable {
    let command: String
  }

  private struct TestMessage: Codable {
    let kind: String
  }

  private struct CallbackCounts {
    var connected = 0
    var disconnected = 0
  }

  private var socketDirectoryURL: URL!
  private var socketPath: String!

  override func setUpWithError() throws {
    try super.setUpWithError()

    socketDirectoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("easybar-agent-client-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: socketDirectoryURL,
      withIntermediateDirectories: true
    )

    socketPath = socketDirectoryURL.appendingPathComponent("agent.sock").path
  }

  override func tearDownWithError() throws {
    if let socketDirectoryURL {
      try? FileManager.default.removeItem(at: socketDirectoryURL)
    }
    try super.tearDownWithError()
  }

  func testStopRunsDisconnectCallbackForActiveConnection() async throws {
    let logger = ProcessLogger(label: "agent.socket.client.tests", minimumLevel: .error)
    let server = LineSocketServerTransport<Void, TestRequest, TestMessage>(
      socketPath: socketPath,
      serverLabel: "agent socket client tests",
      logger: logger
    )

    server.start { fd, _ in
      server.addSubscriber((), for: fd)
      _ = server.send(TestMessage(kind: "subscribed"), to: fd)
      return .keepOpen
    }
    defer { server.stop() }

    try await waitUntil("server socket to exist") {
      FileManager.default.fileExists(atPath: self.socketPath)
    }

    let callbacks = LockedState(CallbackCounts())
    let client = AgentSocketClient<TestRequest, TestMessage>(
      label: "test agent",
      socketPath: { self.socketPath },
      subscribeRequest: { TestRequest(command: "subscribe") },
      handleMessage: { _ in },
      clearState: {},
      onConnected: {
        callbacks.withLock { $0.connected += 1 }
      },
      onDisconnected: {
        callbacks.withLock { $0.disconnected += 1 }
      },
      logger: logger
    )

    client.start()
    defer { client.stop() }

    try await waitUntil("client to connect") {
      callbacks.withLock { $0.connected == 1 }
    }

    client.stop()

    try await waitUntil("client stop to record disconnect") {
      callbacks.withLock { $0.disconnected == 1 }
    }

    XCTAssertFalse(client.isConnected)
  }

  private func waitUntil(
    _ description: String,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    condition: @escaping () -> Bool
  ) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
      if condition() {
        return
      }

      try await Task.sleep(nanoseconds: 10_000_000)
    }

    XCTFail("Timed out waiting for \(description)")
  }
}
