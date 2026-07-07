import Darwin
import Foundation
import XCTest

@testable import EasyBarShared

final class AgentSocketClientTests: XCTestCase {
  private struct TestRequest: Codable {
    let command: String
  }

  private struct TestMessage: Codable, Equatable {
    let kind: String
  }

  private struct CallbackCounts {
    var connected = 0
    var disconnected = 0
    var decoded = 0
  }

  private var temporaryDirectory: URL!
  private var socketPath: String!

  override func setUpWithError() throws {
    try super.setUpWithError()

    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("easybar-agent-client-tests-")
      .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )

    socketPath = temporaryDirectory.appendingPathComponent("agent.sock").path
  }

  override func tearDownWithError() throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    socketPath = nil
    temporaryDirectory = nil

    try super.tearDownWithError()
  }

  func testStopRunsDisconnectCallbackForActiveConnection() async throws {
    let logger = Self.makeLogger()
    let server = makeServer(logger: logger)

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
      handleMessage: { _ in
        callbacks.withLock { $0.decoded += 1 }
      },
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
    try await waitUntil("client to decode subscribed message") {
      callbacks.withLock { $0.decoded == 1 }
    }

    client.stop()

    try await waitUntil("client stop to record disconnect") {
      callbacks.withLock { $0.disconnected == 1 }
    }

    XCTAssertFalse(client.isConnected)
  }

  func testServerStopClosesKeptOpenSubscriberSocket() async throws {
    let logger = Self.makeLogger()
    let removedSubscribers = LockedState(0)

    let notifyingServer = LineSocketServerTransport<Void, TestRequest, TestMessage>(
      socketPath: socketPath,
      serverLabel: "test agent",
      logger: logger,
      onSubscriberRemoved: { _ in
        removedSubscribers.withLock { $0 += 1 }
      }
    )

    notifyingServer.start { fd, _ in
      notifyingServer.addSubscriber((), for: fd)
      _ = notifyingServer.send(TestMessage(kind: "subscribed"), to: fd)
      return .keepOpen
    }
    defer { notifyingServer.stop() }

    try await waitUntil("server socket to exist") {
      FileManager.default.fileExists(atPath: self.socketPath)
    }

    let response: TestMessage = try LineSocketClientTransport<TestRequest, TestMessage>(
      socketPath: socketPath
    ).send(request: TestRequest(command: "subscribe"))

    XCTAssertEqual(response, TestMessage(kind: "subscribed"))

    notifyingServer.stop()

    try await waitUntil("subscriber removal callback") {
      removedSubscribers.withLock { $0 == 1 }
    }
  }

  private func makeServer(logger: ProcessLogger)
    -> LineSocketServerTransport<Void, TestRequest, TestMessage>
  {
    LineSocketServerTransport(
      socketPath: socketPath,
      serverLabel: "test agent",
      logger: logger
    )
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

  private static func makeLogger() -> ProcessLogger {
    ProcessLogger(
      label: "easybar.shared.agent-socket-client.tests",
      minimumLevel: .error,
      outputStream: nil,
      errorStream: nil
    )
  }
}
