import EasyBarShared
import XCTest

@testable import EasyBarApp

final class LuaCommandRunnerTests: XCTestCase {
  private let defaultLimits = LuaCommandRunner.Limits(
    timeoutSeconds: 1,
    maxOutputBytes: 1024
  )

  func testRunExecutesShellCommandAndReturnsOutput() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(command: "printf '0'", limits: defaultLimits)

    XCTAssertEqual(result.output, "0")
    XCTAssertEqual(result.status, 0)
  }

  func testRunCapturesCombinedOutputAndExitStatus() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(command: "printf 'oops' >&2; exit 7", limits: defaultLimits)

    XCTAssertEqual(result.output, "oops")
    XCTAssertEqual(result.status, 7)
  }

  func testRunTerminatesCommandThatExceedsTimeout() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "sleep 2",
      limits: .init(timeoutSeconds: 0.1, maxOutputBytes: 1024)
    )

    XCTAssertEqual(result.status, LuaCommandRunner.Limits.timedOutStatus)
  }

  func testRunTerminatesCommandThatExceedsOutputLimit() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "python3 - <<'PY'\nprint('x' * 4096)\nPY",
      limits: .init(timeoutSeconds: 1, maxOutputBytes: 128)
    )

    XCTAssertEqual(result.status, LuaCommandRunner.Limits.outputLimitStatus)
    XCTAssertLessThanOrEqual(result.output.utf8.count, 128)
  }

  func testRunReportsCommandNotFoundClearly() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "__easybar_missing_command__",
      limits: defaultLimits
    )

    XCTAssertEqual(result.status, 127)
    XCTAssertTrue(result.output.contains("command not found"))
    XCTAssertTrue(result.output.contains("__easybar_missing_command__"))
  }
}
