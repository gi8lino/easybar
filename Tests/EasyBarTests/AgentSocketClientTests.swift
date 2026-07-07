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

    temporaryDirectory = URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("eb-agent-\(UUID().uuidString)", isDirectory: true)

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

    let clientFD = try connectUnixSocket()
    defer { close(clientFD) }

    try writeLine(#"{"command":"subscribe"}"#, to: clientFD)

    let response = try readMessage(from: clientFD)
    XCTAssertEqual(response, TestMessage(kind: "subscribed"))

    try await waitUntil("subscriber to stay registered") {
      notifyingServer.subscribersSnapshot().count == 1
    }

    notifyingServer.stop()

    try await waitUntil("server stop to close subscriber socket") {
      self.socketIsClosed(clientFD)
    }
    try await waitUntil("subscriber removal callback") {
      removedSubscribers.withLock { $0 == 1 }
    }
  }

  func testClientDisconnectRemovesKeptOpenSubscriberSocket() async throws {
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

    try await waitUntil("subscriber removal callback") {
      removedSubscribers.withLock { $0 == 1 }
    }
  }

  func testServerStopWakesIdleClientReadTask() async throws {
    let logger = Self.makeLogger()
    let server = makeServer(logger: logger)

    server.start { _, _ in
      XCTFail("idle client should not dispatch a request")
      return .close
    }
    defer { server.stop() }

    try await waitUntil("server socket to exist") {
      FileManager.default.fileExists(atPath: self.socketPath)
    }

    let clientFD = try connectUnixSocket()
    defer { close(clientFD) }

    server.stop()

    try await waitUntil("idle client socket to be closed") {
      self.socketIsClosed(clientFD)
    }
  }

  func testServerCanRestartOnSameSocketPathAfterStopWithoutClients() async throws {
    let logger = Self.makeLogger()
    let firstServer = makeServer(logger: logger)

    firstServer.start { _, _ in
      XCTFail("server without clients should not dispatch a request")
      return .close
    }

    try await waitUntil("first server socket to exist") {
      FileManager.default.fileExists(atPath: self.socketPath)
    }

    firstServer.stop()

    try await waitUntil("first server socket to be removed") {
      !FileManager.default.fileExists(atPath: self.socketPath)
    }

    let secondServer = makeServer(logger: logger)
    secondServer.start { fd, _ in
      _ = secondServer.send(TestMessage(kind: "pong"), to: fd)
      return .close
    }
    defer { secondServer.stop() }

    try await waitUntil("restarted server socket to exist") {
      FileManager.default.fileExists(atPath: self.socketPath)
    }

    let response: TestMessage = try LineSocketClientTransport<TestRequest, TestMessage>(
      socketPath: socketPath
    ).send(request: TestRequest(command: "ping"))

    XCTAssertEqual(response, TestMessage(kind: "pong"))
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

  private func connectUnixSocket() throws -> Int32 {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    XCTAssertGreaterThanOrEqual(fd, 0)

    guard fd >= 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }

    var address = try makeSockAddrUn(path: socketPath)
    let addressLength = socklen_t(MemoryLayout<sockaddr_un>.size)
    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, addressLength)
      }
    }

    guard result == 0 else {
      let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
      close(fd)
      throw error
    }

    return fd
  }

  private func writeLine(_ line: String, to fd: Int32) throws {
    let payload = Data((line + "\n").utf8)

    try payload.withUnsafeBytes { rawBuffer in
      guard let baseAddress = rawBuffer.baseAddress else { return }

      var sent = 0
      while sent < payload.count {
        let count = write(fd, baseAddress.advanced(by: sent), payload.count - sent)

        if count > 0 {
          sent += count
          continue
        }

        if count < 0, errno == EINTR {
          continue
        }

        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
      }
    }
  }

  private func readMessage(from fd: Int32) throws -> TestMessage {
    let line = try readLine(from: fd)
    return try JSONDecoder().decode(TestMessage.self, from: Data(line.utf8))
  }

  private func readLine(from fd: Int32) throws -> String {
    var bytes: [UInt8] = []
    var byte = UInt8(0)

    while true {
      var pollFD = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
      let pollResult = poll(&pollFD, 1, 1_000)

      if pollResult == 0 {
        throw NSError(
          domain: NSPOSIXErrorDomain,
          code: Int(ETIMEDOUT),
          userInfo: [NSLocalizedDescriptionKey: "timed out waiting for socket line"]
        )
      }

      if pollResult < 0 {
        if errno == EINTR {
          continue
        }

        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
      }

      if (pollFD.revents & Int16(POLLIN)) == 0 {
        throw NSError(
          domain: NSPOSIXErrorDomain,
          code: 0,
          userInfo: [NSLocalizedDescriptionKey: "socket closed before newline"]
        )
      }

      let count = read(fd, &byte, 1)

      if count > 0 {
        if byte == 0x0A {
          return String(decoding: bytes, as: UTF8.self)
        }

        bytes.append(byte)
        continue
      }

      if count == 0 {
        throw NSError(
          domain: NSPOSIXErrorDomain,
          code: 0,
          userInfo: [NSLocalizedDescriptionKey: "socket closed before newline"]
        )
      }

      if errno == EINTR {
        continue
      }

      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
  }

  private func socketIsClosed(_ fd: Int32) -> Bool {
    var buffer = [UInt8](repeating: 0, count: 1)
    let result = recv(fd, &buffer, buffer.count, MSG_DONTWAIT)

    if result == 0 {
      return true
    }

    if result < 0 {
      return errno != EAGAIN && errno != EWOULDBLOCK
    }

    return false
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
