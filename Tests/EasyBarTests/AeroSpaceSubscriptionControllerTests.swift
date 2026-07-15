import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class AeroSpaceSubscriptionControllerTests: XCTestCase {
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
      handler?(Data(line.utf8))
    }

    func emitErrorLine(_ line: String) {
      let handler = lock.withLock { errorDataHandler }
      handler?(Data((line + "\n").utf8))
    }

    func terminate(status: Int32) {
      let handler = lock.withLock { () -> (@Sendable (AeroSpaceSubscriptionSession) -> Void)? in
        terminationStatusValue = status
        let handler = terminationHandler
        terminationHandler = nil
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

  private final class RecordingReconnectScheduler: AeroSpaceReconnectScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var actions: [@Sendable () -> Void] = []
    private(set) var cancelCount = 0
    private(set) var resetDelayCount = 0

    var scheduledCount: Int {
      lock.withLock { actions.count }
    }

    func schedule(_ action: @escaping @Sendable () -> Void) {
      lock.withLock {
        actions.append(action)
      }
    }

    func cancel() {
      lock.withLock {
        cancelCount += 1
        actions.removeAll()
      }
    }

    func resetDelay() {
      lock.withLock {
        resetDelayCount += 1
      }
    }

    func runNextScheduledAction() -> Bool {
      let action = lock.withLock { () -> (@Sendable () -> Void)? in
        guard !actions.isEmpty else { return nil }
        return actions.removeFirst()
      }

      guard let action else { return false }
      action()
      return true
    }
  }

  func testReconnectsWhenSubscriptionExits() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let scheduler = RecordingReconnectScheduler()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      scheduler: scheduler
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertEqual(launcher.launchCount, 1)
    launcher.subscription(at: 0)?.terminate(status: 3)

    XCTAssertEqual(scheduler.scheduledCount, 1)
    XCTAssertTrue(scheduler.runNextScheduledAction())
    XCTAssertEqual(launcher.launchCount, 2)
  }

  func testDoesNotReconnectWhenExecutableDisappears() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let scheduler = RecordingReconnectScheduler()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      scheduler: scheduler
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertEqual(launcher.launchCount, 1)
    launcher.setAvailable(false)
    launcher.subscription(at: 0)?.terminate(status: 3)

    XCTAssertEqual(scheduler.scheduledCount, 0)
    XCTAssertEqual(launcher.launchCount, 1)
  }

  func testSchedulesReconnectForEachCrash() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let scheduler = RecordingReconnectScheduler()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      scheduler: scheduler
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertEqual(launcher.launchCount, 1)
    launcher.subscription(at: 0)?.terminate(status: 3)
    XCTAssertEqual(scheduler.scheduledCount, 1)

    XCTAssertTrue(scheduler.runNextScheduledAction())
    XCTAssertEqual(launcher.launchCount, 2)
    launcher.subscription(at: 1)?.terminate(status: 3)
    XCTAssertEqual(scheduler.scheduledCount, 1)

    XCTAssertTrue(scheduler.runNextScheduledAction())
    XCTAssertEqual(launcher.launchCount, 3)
  }

  func testResetsReconnectBackoffAfterEventLine() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let scheduler = RecordingReconnectScheduler()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      scheduler: scheduler
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertEqual(launcher.launchCount, 1)
    launcher.subscription(at: 0)?.emitOutputLine(#"{"_event":"focused-workspace-changed"}"#)

    XCTAssertEqual(scheduler.resetDelayCount, 1)
    launcher.subscription(at: 0)?.terminate(status: 3)
    XCTAssertEqual(scheduler.scheduledCount, 1)

    XCTAssertTrue(scheduler.runNextScheduledAction())
    XCTAssertEqual(launcher.launchCount, 2)
  }

  func testStopCancelsPendingReconnect() throws {
    let logger = Self.makeLogger()
    let launcher = FakeSubscriptionLauncher()
    let scheduler = RecordingReconnectScheduler()
    let controller = Self.makeController(
      logger: logger,
      launcher: launcher,
      scheduler: scheduler
    )

    controller.start()
    XCTAssertEqual(launcher.launchCount, 1)
    launcher.subscription(at: 0)?.terminate(status: 3)
    XCTAssertEqual(scheduler.scheduledCount, 1)

    controller.stop()

    XCTAssertEqual(scheduler.cancelCount, 2)
    XCTAssertFalse(scheduler.runNextScheduledAction())
    XCTAssertEqual(launcher.launchCount, 1)
  }

  private static func makeController(
    logger: ProcessLogger,
    launcher: FakeSubscriptionLauncher,
    scheduler: RecordingReconnectScheduler
  ) -> AeroSpaceSubscriptionController {
    AeroSpaceSubscriptionController(
      logger: logger,
      subscriptionLauncher: launcher,
      reconnectScheduler: scheduler,
      handleEvent: { _ in }
    )
  }

  private static func makeLogger() -> ProcessLogger {
    ProcessLogger(
      label: "easybar.app.services.aerospace.subscription.tests",
      minimumLevel: .error,
      outputStream: nil,
      errorStream: nil
    )
  }
}
