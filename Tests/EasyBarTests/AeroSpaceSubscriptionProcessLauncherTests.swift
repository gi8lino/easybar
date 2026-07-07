import Foundation
import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class AeroSpaceSubscriptionProcessLauncherTests: XCTestCase {
  func testProcessLauncherReadsSubscriptionOutputAndTermination() throws {
    let logger = Self.makeLogger()
    let fixtureURL = Self.fixtureURL()

    XCTAssertTrue(
      FileManager.default.isExecutableFile(atPath: fixtureURL.path),
      "Expected executable fixture at \(fixtureURL.path)"
    )

    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { fixtureURL.path }
    )
    let launcher = ProcessAeroSpaceSubscriptionLauncher(commandRunner: runner)

    XCTAssertTrue(
      launcher.canLaunchSubscription(arguments: AeroSpaceSubscriptionEvent.subscribeArguments)
    )

    guard
      let session = launcher.makeSubscription(
        arguments: AeroSpaceSubscriptionEvent.subscribeArguments
      )
    else {
      XCTFail("Expected process-backed subscription session")
      return
    }

    let outputExpectation = expectation(description: "subscription output")
    let terminationExpectation = expectation(description: "subscription termination")
    let outputLines = LockedState([String]())
    let terminationStatus = LockedState<Int32?>(nil)

    try session.start(
      onOutputData: { data in
        let text = String(decoding: data, as: UTF8.self)
        let lines =
          text
          .split(separator: "\n")
          .map(String.init)

        outputLines.withLock { outputLines in
          outputLines.append(contentsOf: lines)
        }
        outputExpectation.fulfill()
      },
      onErrorData: { _ in },
      onTermination: { finishedSession in
        terminationStatus.withLock { status in
          status = finishedSession.terminationStatus
        }
        finishedSession.invalidate()
        terminationExpectation.fulfill()
      }
    )
    defer { session.stop() }

    wait(for: [outputExpectation, terminationExpectation], timeout: 2.0)

    XCTAssertEqual(terminationStatus.withLock { $0 }, 0)
    XCTAssertTrue(
      outputLines.withLock { lines in
        lines.contains(#"{"_event":"focused-workspace-changed"}"#)
      }
    )
  }

  private static func fixtureURL() -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // Tests/EasyBarTests
      .deletingLastPathComponent()  // Tests
      .deletingLastPathComponent()  // repository root
      .appendingPathComponent("scripts/test/mock-aerospace-subscribe.sh")
  }

  private static func makeLogger() -> ProcessLogger {
    ProcessLogger(
      label: "easybar.app.services.aerospace.subscription.process-launcher.tests",
      minimumLevel: .error,
      outputStream: nil,
      errorStream: nil
    )
  }
}
