import EasyBarShared
import XCTest

final class SchedulerSleeperTests: XCTestCase {
  private struct ImmediateSleeper: AsyncSleeper {
    func sleep(nanoseconds: UInt64) async throws {}
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
}
