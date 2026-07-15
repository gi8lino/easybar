import EasyBarShared
import XCTest

final class AuthorizationLifecycleTests: XCTestCase {
  private struct ImmediateSleeper: AsyncSleeper {
    func sleep(nanoseconds: UInt64) async throws {}
  }

  func testStopInvalidatesCallbackAndRetryWork() {
    let lifecycle = AuthorizationLifecycle(
      logger: ProcessLogger(label: "test"),
      delays: [0],
      sleeper: ImmediateSleeper()
    )
    var callbackCount = 0
    let session = lifecycle.start {
      callbackCount += 1
    }

    lifecycle.stop()
    lifecycle.notify(session)
    let scheduled = lifecycle.scheduleRetry(for: session) { _ in
      XCTFail("stopped authorization session retried")
    }

    XCTAssertFalse(lifecycle.isCurrent(session))
    XCTAssertFalse(scheduled)
    XCTAssertEqual(callbackCount, 0)
  }

  func testStartingAgainInvalidatesThePreviousGeneration() {
    let lifecycle = AuthorizationLifecycle(
      logger: ProcessLogger(label: "test"),
      delays: [0],
      sleeper: ImmediateSleeper()
    )
    var oldCallbackCount = 0
    var newCallbackCount = 0
    let oldSession = lifecycle.start {
      oldCallbackCount += 1
    }
    let newSession = lifecycle.start {
      newCallbackCount += 1
    }

    lifecycle.notify(oldSession)
    lifecycle.notify(newSession)

    XCTAssertFalse(lifecycle.isCurrent(oldSession))
    XCTAssertTrue(lifecycle.isCurrent(newSession))
    XCTAssertEqual(oldCallbackCount, 0)
    XCTAssertEqual(newCallbackCount, 1)
  }

  func testRetryRunsOnlyForTheCurrentGeneration() {
    let retry = expectation(description: "current generation retried")
    let lifecycle = AuthorizationLifecycle(
      logger: ProcessLogger(label: "test"),
      delays: [0],
      sleeper: ImmediateSleeper()
    )
    let oldSession = lifecycle.start {}
    let currentSession = lifecycle.start {}

    XCTAssertFalse(
      lifecycle.scheduleRetry(for: oldSession) { _ in
        XCTFail("stale authorization generation retried")
      })
    XCTAssertTrue(
      lifecycle.scheduleRetry(for: currentSession) { session in
        XCTAssertTrue(lifecycle.isCurrent(session))
        retry.fulfill()
      })

    wait(for: [retry], timeout: 1)
  }
}
