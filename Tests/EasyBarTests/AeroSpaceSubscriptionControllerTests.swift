import XCTest

@testable import EasyBarApp
@testable import EasyBarShared

final class AeroSpaceSubscriptionControllerTests: XCTestCase {
  func testReconnectsWhenProcessExits() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        exit 3
        """
    )

    let logger = Self.makeLogger()
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01, 0.01],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }

    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 2))
  }

  func testDoesNotReconnectWhenExecutableDisappears() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        rm "$0"
        exit 3
        """
    )

    let logger = Self.makeLogger()
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: {
        FileManager.default.isExecutableFile(atPath: scriptURL.path) ? scriptURL.path : nil
      }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 1))
    Thread.sleep(forTimeInterval: 0.08)

    XCTAssertEqual(Self.launchCount(at: countURL), 1)
  }

  func testAdvancesReconnectBackoffAcrossCrashes() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        exit 3
        """
    )

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = Self.makeFileLogger(logURL: logURL)
    defer { logger.configureFileLogging(enabled: false, path: "") }
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01, 0.05],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 3))
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertTrue(output.contains("delay=0.01"))
    XCTAssertTrue(output.contains("delay=0.05"))
  }

  func testResetsReconnectBackoffAfterEventLine() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        if [ "$count" -eq 2 ]; then
          echo '{"_event":"focused-workspace-changed"}'
        fi
        exit 3
        """
    )

    let logURL = directoryURL.appendingPathComponent("process.log")
    let logger = Self.makeFileLogger(logURL: logURL)
    defer { logger.configureFileLogging(enabled: false, path: "") }
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.01, 0.05],
      handleEvent: { _ in }
    )

    controller.start()
    defer { controller.stop() }
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 4))
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: logURL, encoding: .utf8)
    XCTAssertGreaterThanOrEqual(output.components(separatedBy: "delay=0.01").count - 1, 2)
  }

  func testStopCancelsPendingReconnect() throws {
    let directoryURL = try Self.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let countURL = directoryURL.appendingPathComponent("subscribe-count")
    let scriptURL = directoryURL.appendingPathComponent("aerospace")
    try Self.writeCountingScript(
      at: scriptURL,
      countURL: countURL,
      body:
        """
        exit 3
        """
    )

    let logger = Self.makeLogger()
    let runner = AeroSpaceCommandRunner(
      logger: logger,
      executablePathResolver: { scriptURL.path }
    )
    let controller = AeroSpaceSubscriptionController(
      commandRunner: runner,
      logger: logger,
      reconnectDelays: [0.2],
      handleEvent: { _ in }
    )

    controller.start()
    XCTAssertTrue(Self.waitForLaunchCount(at: countURL, minimum: 1))
    controller.stop()
    Thread.sleep(forTimeInterval: 0.3)

    XCTAssertEqual(Self.launchCount(at: countURL), 1)
  }

  private static func makeTemporaryDirectory() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "easybar-aerospace-subscribe-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
  }

  private static func writeCountingScript(
    at scriptURL: URL,
    countURL: URL,
    body: String
  ) throws {
    try """
    #!/bin/sh
    count_file='\(shellQuoted(countURL.path))'
    count="$(cat "$count_file" 2>/dev/null || echo 0)"
    count=$((count + 1))
    echo "$count" > "$count_file"
    \(body)
    """.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: scriptURL.path
    )
  }

  private static func launchCount(at countURL: URL) -> Int {
    (try? String(contentsOf: countURL, encoding: .utf8))
      .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
  }

  private static func waitForLaunchCount(
    at countURL: URL,
    minimum: Int,
    timeout: TimeInterval = 1
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if launchCount(at: countURL) >= minimum {
        return true
      }
      Thread.sleep(forTimeInterval: 0.01)
    }
    return false
  }

  private static func makeLogger() -> ProcessLogger {
    ProcessLogger(
      label: "easybar.app.services.aerospace.subscribe",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil
    )
  }

  private static func makeFileLogger(logURL: URL) -> ProcessLogger {
    let logger = makeLogger()
    logger.configureFileLogging(enabled: true, path: logURL.path)
    return logger
  }

  private static func shellQuoted(_ value: String) -> String {
    value.replacingOccurrences(of: "'", with: "'\\''")
  }
}
