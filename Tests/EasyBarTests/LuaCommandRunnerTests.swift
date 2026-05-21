import EasyBarShared
import XCTest

@testable import EasyBarApp

final class LuaCommandRunnerTests: XCTestCase {
  func testRunExecutesShellCommandAndReturnsOutput() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(command: "printf '0'")

    XCTAssertEqual(result.output, "0")
    XCTAssertEqual(result.status, 0)
  }

  func testRunCapturesCombinedOutputAndExitStatus() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(command: "printf 'oops' >&2; exit 7")

    XCTAssertEqual(result.output, "oops")
    XCTAssertEqual(result.status, 7)
  }
}
