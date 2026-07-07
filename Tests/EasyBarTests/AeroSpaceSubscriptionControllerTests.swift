import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class AeroSpaceSubscriptionControllerTests: XCTestCase {
  private struct ImmediateSleeper: AsyncSleeper {
    func sleep(nanoseconds: UInt64) async throws {}
  }

  private final class PausedSleeper: AsyncSleeper, @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func sleep(nanoseconds: UInt64) async throws {
      try await withCheckedThrowingContinuation { continuation in
        lock.lock()
        continuations.append(continuation)
        lock.unlock()
      }
    }

    func resumeAll() {
      let continuations = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
        let continuations = self.continuations
        self.continuations.removeAll()
        return continuations
      }

      for continuation in continuations {
        continuation.resume()
      }
    }

    func waitForPendingSleep(timeout: TimeInterval = 1.0) -> Bool {
      AeroSpaceSubscriptionControllerTests.waitUntil(timeout: timeout) {
        self.lock.withLock { !self.continuations.isEmpty }
      }
    }
  }

  private final class FakeSubscriptionLauncher: AeroSpaceSubscriptionLaunching, @unchecked Sendable {
    private let lock = NSLock()
    private var subscriptions: [FakeSubscriptionSession] = []
    private var available = true

    func canLaunchSubscription(arguments: [String]) -> Bool {
      lock.withLock { available }
    }

    func makeSubscription(arguments: [String]) -> AeroSpaceSubscriptionSession? {
      lock.withLock {
        guard available else { return nil }
        let subscription = FakeSubscriptionSession()
        subscriptions.append(subscription)
        return subscription
      }
    }

    func setAvailable(_ available: Bool) {
      lock.withLock {
        self.available = available
      }
    }

    var launchCount: Int {
      lock.withLock { subscriptions.count }
    }

    func subscription(at index: Int) -> FakeSubscriptionSession? {
      lock.withLock {
        guard subscriptions.indices.contains(index) else { return nil }
        return subscriptions[index]
      }
    }

    func waitForLaunchCount(_ minimum: Int, timeout: TimeInterval = 1.0) -> Bool {
      AeroSpaceSubscriptionControllerTests.waitUntil(timeout: timeout) {
        self.launchCount >= minimum
      }
    }
  }

  private final class FakeSubscriptionSession: AeroSpaceSubscriptionSession, @unchecked Sendable {
    private let lock = NSLock()
    private var outputDataHandler: (@Sendable (Data) -> Void)?
    private var errorDataHandler: (@Sendable (Data) -> Void)?
    private var terminationHandler: (@Sendable (AeroSpaceSubscriptionSession) -> Void)?
    private var terminationStatusValue: Int32 = 0
    private(set) var started = false
    private(set) var stopped = false
    private(set) var invalidated = false

    var terminationStatus: Int32 {
      lock.withLock { terminationStatusValue }
    }

    func start(
      onOutputData: @escaping @Sendable (Data) -> Void,
      onErrorData: @escaping @Sendable (Data) -> Void,
      onTermination: @escaping @Sendable (AeroSpaceSubscriptionSession) -> Void
    ) throws {
      lock.withLock {
        started = true
        outputDataHandler = onOutputData
        errorDataHandler = onErrorData
        terminationHandler = onTermination
      }
    }

    func stop() {
      lock.withLock {
        stopped = true
        clearHandlers()
      }
    }

    func invalidate() {
      lock.withLock {
        invalidated = true
        clearHandlers()
      }
    }

    func emitOutputLine(_ line: String) {
      let handler = lock.withLock { outputDataHandler }
      handler?(Data((line + "\n").utf8))
    }

    func emitErrorLine(_ line: String) {
      let handler = lock.withLock { errorDataHandler }
      handler?(Data((line + "\n").utf8))
    }

    func terminate(status: Int32) {
      let handler = lock.withLock { () -> (@Sendable (AeroSpaceSubscriptionSession) -> Void)? in
        terminationStatusValue = status
        let handler = terminationHandler
        return handler
      }
      handler?(self)
    }

    private func clearHandlers() {
      outputDataHandler = nil
      errorDataHandler = nil
      terminationHandler = nil
    }
  }

  func testReconnectsWhenProcessExits() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      reconnectDelays: [0.01, 0.01],
      sleeper: ImmediateSleeper()
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertTrue(launcher.waitForLaunchCount(1))
    launcher.subscription(at: 0)?.terminate(status: 3)

    XCTAssertTrue(launcher.waitForLaunchCount(2))
  }

  func testDoesNotReconnectWhenExecutableDisappears() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      reconnectDelays: [0.01],
      sleeper: ImmediateSleeper()
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertTrue(launcher.waitForLaunchCount(1))
    launcher.setAvailable(false)
    launcher.subscription(at: 0)?.terminate(status: 3)

    XCTAssertFalse(launcher.waitForLaunchCount(2, timeout: 0.1))
    XCTAssertEqual(launcher.launchCount, 1)
  }

  func testAdvancesReconnectBackoffAcrossCrashes() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = Self.makeFileLogger(logURL: logURL)
    defer { logger.configureFileLogging(enabled: false, path: "") }

    let launcher = FakeSubscriptionLauncher()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      reconnectDelays: [0.01, 0.05],
      sleeper: ImmediateSleeper()
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertTrue(launcher.waitForLaunchCount(1))
    launcher.subscription(at: 0)?.terminate(status: 3)
    XCTAssertTrue(launcher.waitForLaunchCount(2))
    launcher.subscription(at: 1)?.terminate(status: 3)
    XCTAssertTrue(launcher.waitForLaunchCount(3))

    logger.configureFileLogging(enabled: false, path: "")
    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertTrue(output.contains("delay=0.01"))
    XCTAssertTrue(output.contains("delay=0.05"))
  }

  func testResetsReconnectBackoffAfterEventLine() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = Self.makeFileLogger(logURL: logURL)
    defer { logger.configureFileLogging(enabled: false, path: "") }

    let launcher = FakeSubscriptionLauncher()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      reconnectDelays: [0.01, 0.05],
      sleeper: ImmediateSleeper()
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertTrue(launcher.waitForLaunchCount(1))
    launcher.subscription(at: 0)?.terminate(status: 3)
    XCTAssertTrue(launcher.waitForLaunchCount(2))

    launcher.subscription(at: 1)?.emitOutputLine(#"{"_event":"focused-workspace-changed"}"#)
    launcher.subscription(at: 1)?.terminate(status: 3)
    XCTAssertTrue(launcher.waitForLaunchCount(3))

    logger.configureFileLogging(enabled: false, path: "")
    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertGreaterThanOrEqual(output.components(separatedBy: "delay=0.01").count - 1, 2)
  }

  func testStopCancelsPendingReconnect() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let sleeper = PausedSleeper()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      reconnectDelays: [0.2],
      sleeper: sleeper
    )

    controller.start()
    XCTAssertTrue(launcher.waitForLaunchCount(1))
    launcher.subscription(at: 0)?.terminate(status: 3)
    XCTAssertTrue(sleeper.waitForPendingSleep())

    controller.stop()
    sleeper.resumeAll()

    XCTAssertFalse(launcher.waitForLaunchCount(2, timeout: 0.1))
    XCTAssertEqual(launcher.launchCount, 1)
  }

  private static func makeController(
    logger: ProcessLogger,
    launcher: FakeSubscriptionLauncher,
    reconnectDelays: [TimeInterval],
    sleeper: any AsyncSleeper
  ) -> AeroSpaceSubscriptionController {
    AeroSpaceSubscriptionController(
      commandRunner: makeCommandRunner(logger: logger),
      logger: logger,
      subscriptionLauncher: launcher,
      reconnectDelays: reconnectDelays,
      sleeper: sleeper,
      handleEvent: { _ in }
    )
  }

  private static func makeCommandRunner(logger: ProcessLogger) -> AeroSpaceCommandRunner {
    AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { nil }
    )
  }

  private static func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-aerospace-subscription-tests-\(UUID().uuidString)",
        isDirectory: true
      )
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
  }

  private static func makeLogger() -> ProcessLogger {
    ProcessLogger(
      label: "easybar.app.services.aerospace.subscription.tests",
      minimumLevel: .error,
      outputStream: nil,
      errorStream: nil
    )
  }

  private static func makeFileLogger(logURL: URL) -> ProcessLogger {
    let logger = ProcessLogger(
      label: "easybar.app.services.aerospace.subscription.tests",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
    logger.configureFileLogging(enabled: true, path: logURL.path)
    return logger
  }

  private static func waitUntil(
    timeout: TimeInterval,
    interval: TimeInterval = 0.005,
    _ condition: () -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      if condition() {
        return true
      }
      Thread.sleep(forTimeInterval: interval)
    }

    return condition()
  }
}
