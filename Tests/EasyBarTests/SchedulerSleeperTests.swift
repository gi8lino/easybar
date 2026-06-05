import EasyBarShared
import XCTest

final class SchedulerSleeperTests: XCTestCase {
  private struct ImmediateSleeper: AsyncSleeper {
    func sleep(nanoseconds: UInt64) async throws {}
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
}
