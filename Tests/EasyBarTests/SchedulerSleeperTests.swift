import XCTest

@testable import EasyBarShared

final class SchedulerSleeperTests: XCTestCase {
  private struct ImmediateSleeper: AsyncSleeper {
    func sleep(nanoseconds: UInt64) async throws {}
  }

  private enum TestSleeperError: Error {
    case failed
  }

  private struct ThrowingSleeper: AsyncSleeper {
    func sleep(nanoseconds: UInt64) async throws {
      throw TestSleeperError.failed
    }
  }

  private final class ThrowingOnceSleeper: AsyncSleeper, @unchecked Sendable {
    private let callState = LockedState(0)

    func sleep(nanoseconds: UInt64) async throws {
      let call = callState.withLock { count -> Int in
        count += 1
        return count
      }
      if call == 1 {
        throw TestSleeperError.failed
      }
    }
  }

  private final class RecordingSleeper: AsyncSleeper, @unchecked Sendable {
    private let state = LockedState([UInt64]())

    var sleeps: [UInt64] {
      state.withLock { $0 }
    }

    func sleep(nanoseconds: UInt64) async throws {
      state.withLock { $0.append(nanoseconds) }
    }
  }

  func testDebouncedActionSchedulerCanUseInjectedSleeper() {
    let expectation = expectation(description: "debounced action fired")
    let scheduler = DebouncedActionScheduler(
      delay: 60,
      logger: ProcessLogger(label: "test"),
      sleeper: ImmediateSleeper()
    )

    scheduler.schedule {
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  func testDebouncedActionSchedulerCanUsePerCallDelay() {
    let expectation = expectation(description: "debounced action fired")
    let scheduler = DebouncedActionScheduler(
      delay: 60,
      logger: ProcessLogger(label: "test"),
      sleeper: ImmediateSleeper()
    )

    scheduler.schedule(after: 120) {
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  func testAuthorizationRetryBackoffCanUseInjectedSleeper() {
    let expectation = expectation(description: "retry fired")
    let backoff = AuthorizationRetryBackoff(
      delays: [60],
      logger: ProcessLogger(label: "test"),
      sleeper: ImmediateSleeper()
    )

    backoff.schedule {
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1)
  }

  func testAuthorizationRetryBackoffRunsImmediateSleeperRetries() {
    let backoff = AuthorizationRetryBackoff(
      delays: [0],
      logger: ProcessLogger(label: "test"),
      sleeper: ImmediateSleeper()
    )

    for attempt in 0..<10 {
      let retry = expectation(description: "immediate authorization retry \(attempt) fired")
      backoff.schedule {
        retry.fulfill()
      }
      wait(for: [retry], timeout: 1)
    }
  }

  func testBackoffSchedulerUsesCappedIncrementalDelays() {
    let sleeper = RecordingSleeper()
    let scheduler = BackoffScheduler(
      label: "test retry",
      delays: [0.001, 0.002],
      logger: ProcessLogger(label: "test"),
      sleeper: sleeper
    )
    let first = expectation(description: "first retry fired")
    let second = expectation(description: "second retry fired")
    let third = expectation(description: "third retry fired")

    scheduler.schedule { first.fulfill() }
    wait(for: [first], timeout: 1)

    scheduler.schedule { second.fulfill() }
    wait(for: [second], timeout: 1)

    scheduler.schedule { third.fulfill() }
    wait(for: [third], timeout: 1)

    XCTAssertEqual(sleeper.sleeps, [1_000_000, 2_000_000, 2_000_000])
  }

  func testBackoffSchedulerDelayOverrideDoesNotAdvanceBackoffSequence() {
    let sleeper = RecordingSleeper()
    let scheduler = BackoffScheduler(
      label: "test retry",
      delays: [0.001, 0.002],
      logger: ProcessLogger(label: "test"),
      sleeper: sleeper
    )
    let first = expectation(description: "override retry fired")
    let second = expectation(description: "first backoff retry fired")

    scheduler.schedule(after: 0.005) { first.fulfill() }
    wait(for: [first], timeout: 1)

    scheduler.schedule { second.fulfill() }
    wait(for: [second], timeout: 1)

    XCTAssertEqual(sleeper.sleeps, [5_000_000, 1_000_000])
  }

  func testBackoffSchedulerRunsImmediateSleeperRetries() {
    let scheduler = BackoffScheduler(
      label: "test retry",
      delays: [0],
      logger: ProcessLogger(label: "test"),
      sleeper: ImmediateSleeper()
    )

    for attempt in 0..<10 {
      let retry = expectation(description: "immediate retry \(attempt) fired")
      scheduler.schedule {
        retry.fulfill()
      }
      wait(for: [retry], timeout: 1)
    }
  }

  func testBackoffSchedulerClearsFailedSleepBeforeNextSchedule() {
    let sleeper = ThrowingOnceSleeper()
    let scheduler = BackoffScheduler(
      label: "test retry",
      delays: [0],
      logger: ProcessLogger(label: "test"),
      sleeper: sleeper
    )
    let failedAction = expectation(description: "failed sleep action must not fire")
    failedAction.isInverted = true

    scheduler.schedule {
      failedAction.fulfill()
    }

    XCTAssertTrue(waitUntil { !scheduler.hasScheduledAction })
    wait(for: [failedAction], timeout: 0.02)

    let replacement = expectation(description: "replacement retry accepted")
    scheduler.schedule {
      replacement.fulfill()
    }
    wait(for: [replacement], timeout: 1)
  }

  func testDebouncedActionSchedulerClearsStateAfterSleeperError() {
    let action = expectation(description: "failed sleep action must not fire")
    action.isInverted = true
    let scheduler = DebouncedActionScheduler(
      delay: 0,
      logger: ProcessLogger(label: "test"),
      sleeper: ThrowingSleeper()
    )

    scheduler.schedule {
      action.fulfill()
    }

    XCTAssertTrue(waitUntil { !scheduler.hasPendingAction })
    wait(for: [action], timeout: 0.02)
  }

  func testDebouncedActionSchedulerDoesNotRetainCompletedImmediateTask() {
    let action = expectation(description: "immediate action fired")
    let scheduler = DebouncedActionScheduler(
      delay: 0,
      logger: ProcessLogger(label: "test"),
      sleeper: ImmediateSleeper()
    )

    scheduler.schedule {
      action.fulfill()
    }
    wait(for: [action], timeout: 1)

    XCTAssertTrue(waitUntil { !scheduler.hasPendingAction })
  }

  private func waitUntil(
    timeout: TimeInterval = 1,
    condition: () -> Bool
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() {
        return true
      }
      Thread.sleep(forTimeInterval: 0.001)
    }
    return condition()
  }

  func testSchedulersClampUnsafeDelays() {
    let sleeper = RecordingSleeper()

    let debounced = DebouncedActionScheduler(
      delay: -1,
      logger: ProcessLogger(label: "test"),
      sleeper: sleeper
    )
    let debouncedFired = expectation(description: "negative debounced delay fired")
    debounced.schedule {
      debouncedFired.fulfill()
    }
    wait(for: [debouncedFired], timeout: 1)

    let authorizationBackoff = AuthorizationRetryBackoff(
      delays: [.nan],
      logger: ProcessLogger(label: "test"),
      sleeper: sleeper
    )
    let authorizationRetryFired = expectation(description: "nan authorization retry fired")
    authorizationBackoff.schedule {
      authorizationRetryFired.fulfill()
    }
    wait(for: [authorizationRetryFired], timeout: 1)

    let backoff = BackoffScheduler(
      label: "test retry",
      delays: [.infinity, .greatestFiniteMagnitude],
      logger: ProcessLogger(label: "test"),
      sleeper: sleeper
    )
    let infiniteBackoffFired = expectation(description: "infinite backoff fired")
    let hugeBackoffFired = expectation(description: "huge backoff fired")

    backoff.schedule {
      infiniteBackoffFired.fulfill()
    }
    wait(for: [infiniteBackoffFired], timeout: 1)

    backoff.schedule {
      hugeBackoffFired.fulfill()
    }
    wait(for: [hugeBackoffFired], timeout: 1)

    XCTAssertEqual(sleeper.sleeps, [0, 0, UInt64.max, UInt64.max])
  }

}
