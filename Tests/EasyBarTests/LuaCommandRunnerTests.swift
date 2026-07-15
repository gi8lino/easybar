import EasyBarShared
import Foundation
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

    for _ in 0..<20 {
      let result = await runner.run(command: "printf '0'", limits: defaultLimits)

      XCTAssertEqual(result.output, "0")
      XCTAssertEqual(result.status, 0)
    }
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

  func testRunDoesNotWaitForBackgroundChildHoldingOutputPipe() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let startedAt = Date()
    let result = await runner.run(
      command: "sleep 3 & printf done",
      limits: .init(timeoutSeconds: 1, maxOutputBytes: 1024)
    )
    let elapsedSeconds = Date().timeIntervalSince(startedAt)

    XCTAssertEqual(result.output, "done")
    XCTAssertEqual(result.status, 0)
    XCTAssertLessThan(elapsedSeconds, 1.5)
  }

  func testRunTerminatesChildProcessGroupOnTimeout() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )
    let markerPath = "/tmp/easybar-lua-command-runner-\(UUID().uuidString)"
    defer { try? FileManager.default.removeItem(atPath: markerPath) }

    let result = await runner.run(
      command: "sh -c 'sleep 0.5; touch \"\(markerPath)\"' & wait",
      limits: .init(timeoutSeconds: 0.1, maxOutputBytes: 1024)
    )

    try? await Task.sleep(nanoseconds: 1_000_000_000)

    XCTAssertEqual(result.status, LuaCommandRunner.Limits.timedOutStatus)
    XCTAssertFalse(FileManager.default.fileExists(atPath: markerPath))
  }

  func testRunTerminatesChildProcessGroupOnCancellation() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )
    let markerPath = "/tmp/easybar-lua-command-runner-\(UUID().uuidString)"
    defer { try? FileManager.default.removeItem(atPath: markerPath) }

    let task = Task {
      await runner.run(
        command: "sh -c 'sleep 0.5; touch \"\(markerPath)\"' & wait",
        limits: .init(timeoutSeconds: 5, maxOutputBytes: 1024)
      )
    }

    try? await Task.sleep(nanoseconds: 100_000_000)
    task.cancel()
    let result = await task.value

    try? await Task.sleep(nanoseconds: 1_000_000_000)

    XCTAssertEqual(result.status, LuaCommandRunner.Limits.cancelledStatus)
    XCTAssertFalse(FileManager.default.fileExists(atPath: markerPath))
  }

  func testRunForceKillsCommandThatIgnoresTermination() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let startedAt = Date()
    let result = await runner.run(
      command: "trap '' TERM; while :; do sleep 1; done",
      limits: .init(timeoutSeconds: 0.1, maxOutputBytes: 1024)
    )
    let elapsedSeconds = Date().timeIntervalSince(startedAt)

    XCTAssertEqual(result.status, LuaCommandRunner.Limits.timedOutStatus)
    XCTAssertLessThan(elapsedSeconds, 2.0)
  }

  func testRunAcceptsOutputOneByteBelowLimit() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "python3 -c \"import sys; sys.stdout.write('x' * 127)\"",
      limits: .init(timeoutSeconds: 1, maxOutputBytes: 128)
    )

    XCTAssertEqual(result.status, 0)
    XCTAssertEqual(result.output.utf8.count, 127)
  }

  func testRunAcceptsOutputExactlyAtLimit() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "python3 -c \"import sys; sys.stdout.write('x' * 128)\"",
      limits: .init(timeoutSeconds: 1, maxOutputBytes: 128)
    )

    XCTAssertEqual(result.status, 0)
    XCTAssertEqual(result.output.utf8.count, 128)
  }

  func testRunAcceptsChunkedOutputExactlyAtLimit() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "python3 -c \"import sys; [sys.stdout.write('12345678') for _ in range(16)]\"",
      limits: .init(timeoutSeconds: 1, maxOutputBytes: 128)
    )

    XCTAssertEqual(result.status, 0)
    XCTAssertEqual(result.output.utf8.count, 128)
  }

  func testRunRejectsTheFirstByteBeyondOutputLimit() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    let result = await runner.run(
      command: "python3 -c \"import sys; sys.stdout.write('x' * 129)\"",
      limits: .init(timeoutSeconds: 1, maxOutputBytes: 128)
    )

    XCTAssertEqual(result.status, LuaCommandRunner.Limits.outputLimitStatus)
    XCTAssertEqual(result.output.utf8.count, 128)
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

  func testRunUsesProvidedEnvironment() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    var environment = ProcessInfo.processInfo.environment
    environment["EASYBAR_TEST_COMMAND_ENV"] = "from-app-env"

    let result = await runner.run(
      command: "printf \"$EASYBAR_TEST_COMMAND_ENV\"",
      limits: defaultLimits,
      environment: environment
    )

    XCTAssertEqual(result.output, "from-app-env")
    XCTAssertEqual(result.status, 0)
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

  func testRunClampsUnsafeTimeouts() async {
    let runner = LuaCommandRunner(
      logger: ProcessLogger(label: "lua.command-runner.tests", minimumLevel: .error)
    )

    for timeoutSeconds in [TimeInterval.nan, .infinity, .greatestFiniteMagnitude, -1] {
      let result = await runner.run(
        command: "printf 'ok'",
        limits: .init(timeoutSeconds: timeoutSeconds, maxOutputBytes: 1024)
      )

      XCTAssertEqual(result.output, "ok")
      XCTAssertEqual(result.status, 0)
    }
  }

}
