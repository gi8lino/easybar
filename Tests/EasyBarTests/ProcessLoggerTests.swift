import Foundation
import XCTest

@testable import EasyBarShared

final class ProcessLoggerTests: XCTestCase {
  /// Verifies that info writes typed fields to configured log file.
  func testInfoWritesTypedFieldsToConfiguredLogFile() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.info(
      "network event",
      .field("event", "wifi_change"),
      .field("connected", true),
      .field("rssi", -51)
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(
      output.contains(
        "] [INFO ] network event event=wifi_change connected=true rssi=-51"
      )
    )
  }

  /// Verifies that typed log fields quote whitespace and empty values.
  func testTypedLogFieldsQuoteWhitespaceAndEmptyValues() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.info(
      "formatted fields",
      .field("message", "hello world"),
      .field("empty", "")
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(
      output.contains(#"formatted fields message="hello world" empty="""#)
    )
  }

  /// Verifies that typed log fields escape special characters.
  func testTypedLogFieldsEscapeSpecialCharacters() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.info(
      "escaped fields",
      .field("payload", "line 1\nline\t2"),
      .field("quote", #"say "hi""#)
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(
      output.contains(
        #"escaped fields payload="line 1\nline\t2" quote="say \"hi\"""#
      )
    )
  }

  /// Verifies that typed log fields format nil values.
  func testTypedLogFieldsFormatNilValues() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.info(
      "nil fields",
      .field("ssid", nil)
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("nil fields ssid=nil"))
  }

  /// Verifies that minimum level filters lower severity messages.
  func testMinimumLevelFiltersLowerSeverityMessages() throws {
    let fixture = try makeLogger(label: "easybar", minimumLevel: .warn)
    defer { cleanup(fixture) }

    fixture.logger.trace("trace hidden")
    fixture.logger.debug("debug hidden")
    fixture.logger.info("info hidden")
    fixture.logger.warn("warn visible")
    fixture.logger.error("error visible")

    let output = try readLogAndClose(fixture)

    XCTAssertFalse(output.contains("trace hidden"))
    XCTAssertFalse(output.contains("debug hidden"))
    XCTAssertFalse(output.contains("info hidden"))
    XCTAssertTrue(output.contains("] [WARN ] warn visible subsystem=easybar"))
    XCTAssertTrue(output.contains("] [ERROR] error visible subsystem=easybar"))
  }

  /// Verifies that set minimum level updates runtime filtering.
  func testSetMinimumLevelUpdatesRuntimeFiltering() throws {
    let fixture = try makeLogger(label: "easybar", minimumLevel: .error)
    defer { cleanup(fixture) }

    fixture.logger.debug("debug hidden")
    fixture.logger.setMinimumLevel(.debug)
    fixture.logger.debug("debug visible")

    let output = try readLogAndClose(fixture)

    XCTAssertFalse(output.contains("debug hidden"))
    XCTAssertTrue(output.contains("] [DEBUG] debug visible subsystem=easybar"))
  }

  /// Verifies that child logger shares file output and runtime configuration.
  func testChildLoggerSharesFileOutputAndRuntimeConfiguration() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    let child = fixture.logger.child("network")

    child.info(
      "child event",
      .field("event", "socket_connected")
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(
      output.contains(
        "] [INFO ] child event event=socket_connected"
      )
    )
    XCTAssertFalse(output.contains("subsystem=easybar.network"))
  }

  /// Verifies that empty child logger suffix returns parent logger.
  func testEmptyChildLoggerSuffixReturnsParentLogger() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    let child = fixture.logger.child("  ")

    child.info("parent event")

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("] [INFO ] parent event"))
    XCTAssertFalse(output.contains("easybar."))
  }

  /// Verifies that write raw mirrors unformatted message to log file.
  func testWriteRawMirrorsUnformattedMessageToLogFile() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.writeRaw("plain runtime output", to: nil)

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("plain runtime output\n"))
    XCTAssertFalse(output.contains("[INFO] plain runtime output"))
  }

  /// Verifies that runtime logging configuration updates level and file state.
  func testRuntimeLoggingConfigurationUpdatesLevelAndFileState() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let fileURL = directoryURL.appendingPathComponent("runtime.log")
    let logger = makeQuietLogger(label: "easybar")

    logger.configureRuntimeLogging(
      minimumLevel: .debug,
      fileLoggingEnabled: true,
      fileLoggingPath: fileURL.path
    )

    XCTAssertEqual(logger.minimumLevel, .debug)
    XCTAssertTrue(logger.fileLoggingEnabled)
    XCTAssertEqual(logger.fileLoggingPath, fileURL.path)

    logger.debug("runtime debug")

    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: fileURL, encoding: .utf8)
    XCTAssertTrue(output.contains("] [DEBUG] runtime debug subsystem=easybar"))
  }

  /// Verifies that process startup log writes standard startup block.
  func testProcessStartupLogWritesStandardStartupBlock() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    logProcessStartup(
      processName: "easybar",
      configPath: "/tmp/easybar/config.toml",
      socketPath: "/tmp/easybar/easybar.sock",
      logger: fixture.logger
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(
      output.contains(
        "] [INFO ] process startup process=easybar event=startup"
      )
    )
    XCTAssertTrue(output.contains("run_id="))
    XCTAssertTrue(
      output.contains(
        "] [INFO ] process startup config config_path=/tmp/easybar/config.toml"
      )
    )
    XCTAssertTrue(
      output.contains(
        "] [INFO ] process startup socket socket_path=/tmp/easybar/easybar.sock"
      )
    )
    XCTAssertTrue(
      output.contains(
        "process startup logging logging_enabled=true level=info path=\(fixture.fileURL.path)"
      )
    )
  }

  /// Verifies that process log level normalizes free form values.
  func testProcessLogLevelNormalizesFreeFormValues() {
    XCTAssertEqual(ProcessLogLevel.normalized("trace"), .trace)
    XCTAssertEqual(ProcessLogLevel.normalized(" DEBUG "), .debug)
    XCTAssertEqual(ProcessLogLevel.normalized("info"), .info)
    XCTAssertEqual(ProcessLogLevel.normalized("warn"), .warn)
    XCTAssertEqual(ProcessLogLevel.normalized("warning"), .warn)
    XCTAssertEqual(ProcessLogLevel.normalized("error"), .error)
    XCTAssertNil(ProcessLogLevel.normalized(nil))
    XCTAssertNil(ProcessLogLevel.normalized("verbose"))
  }

  /// Verifies that request-correlated entries include the process run identifier.
  func testRequestLogsIncludeRunIdentifier() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }
    let fileURL = directoryURL.appendingPathComponent("request.log")
    let logger = ProcessLogger(
      label: "easybar",
      minimumLevel: .debug,
      outputStream: nil,
      errorStream: nil,
      runID: "test-run"
    )
    logger.configureFileLogging(enabled: true, path: fileURL.path)
    logger.debug("request started", .field("request_id", "lua-19"))
    logger.configureFileLogging(enabled: false, path: "")

    let output = try String(contentsOf: fileURL, encoding: .utf8)
    XCTAssertTrue(output.contains("request_id=lua-19 run_id=test-run subsystem=easybar"))
    XCTAssertEqual(logger.child("child").runID, "test-run")
  }
}

private struct ProcessLoggerFixture {
  let logger: ProcessLogger
  let directoryURL: URL
  let fileURL: URL
}

/// Creates a logger fixture backed by an isolated temporary log file.
private func makeLogger(
  label: String,
  minimumLevel: ProcessLogLevel = .info
) throws -> ProcessLoggerFixture {
  let directoryURL = try makeTemporaryDirectory()
  let fileURL = directoryURL.appendingPathComponent("process.log")

  let logger = makeQuietLogger(label: label, minimumLevel: minimumLevel)
  logger.configureFileLogging(enabled: true, path: fileURL.path)

  return ProcessLoggerFixture(
    logger: logger,
    directoryURL: directoryURL,
    fileURL: fileURL
  )
}

/// Creates a logger fixture without mirroring output to process streams.
private func makeQuietLogger(
  label: String,
  minimumLevel: ProcessLogLevel = .info,
  rotationPolicy: ProcessLogRotationPolicy = .default
) -> ProcessLogger {
  ProcessLogger(
    label: label,
    minimumLevel: minimumLevel,
    outputStream: nil,
    errorStream: nil,
    rotationPolicy: rotationPolicy
  )
}

/// Creates an isolated temporary directory for file-system assertions.
private func makeTemporaryDirectory() throws -> URL {
  let directoryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("easybar-logging-tests-\(UUID().uuidString)", isDirectory: true)

  try FileManager.default.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
  )

  return directoryURL
}

/// Closes the fixture and returns the log file contents.
private func readLogAndClose(_ fixture: ProcessLoggerFixture) throws -> String {
  fixture.logger.configureFileLogging(enabled: false, path: "")

  return try String(contentsOf: fixture.fileURL, encoding: .utf8)
}

/// Closes and removes resources owned by the logger fixture.
private func cleanup(_ fixture: ProcessLoggerFixture) {
  fixture.logger.configureFileLogging(enabled: false, path: "")
  try? FileManager.default.removeItem(at: fixture.directoryURL)
}

final class ProcessLoggerAdditionalTests: XCTestCase {
  /// Verifies that child logger trims suffix whitespace.
  func testChildLoggerTrimsSuffixWhitespace() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    let child = fixture.logger.child("  network  ")

    child.info("trimmed child")

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("] [INFO ] trimmed child"))
    XCTAssertFalse(output.contains("easybar.  network  "))
  }

  /// Verifies that child logger shares minimum level changes.
  func testChildLoggerSharesMinimumLevelChanges() throws {
    let fixture = try makeLogger(label: "easybar", minimumLevel: .error)
    defer { cleanup(fixture) }

    let child = fixture.logger.child("network")

    child.info("child info hidden")
    fixture.logger.setMinimumLevel(.info)
    child.info("child info visible")

    let output = try readLogAndClose(fixture)

    XCTAssertFalse(output.contains("child info hidden"))
    XCTAssertTrue(output.contains("] [INFO ] child info visible"))
    XCTAssertFalse(output.contains("subsystem=easybar.network"))
  }

  /// Verifies that configure file logging disabled does not create log file.
  func testConfigureFileLoggingDisabledDoesNotCreateLogFile() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let fileURL = directoryURL.appendingPathComponent("disabled.log")
    let logger = makeQuietLogger(label: "easybar")

    logger.configureFileLogging(enabled: false, path: fileURL.path)
    logger.info("stdout only")

    XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    XCTAssertFalse(logger.fileLoggingEnabled)
    XCTAssertEqual(logger.fileLoggingPath, fileURL.path)
  }

  /// Verifies that configure file logging with empty path does not create file handle.
  func testConfigureFileLoggingWithEmptyPathDoesNotCreateFileHandle() {
    let logger = makeQuietLogger(label: "easybar")

    logger.configureFileLogging(enabled: true, path: "")
    logger.info("stdout only")

    XCTAssertTrue(logger.fileLoggingEnabled)
    XCTAssertEqual(logger.fileLoggingPath, "")
  }

  /// Verifies that reconfiguring file logging moves output to new file.
  func testReconfiguringFileLoggingMovesOutputToNewFile() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let firstURL = directoryURL.appendingPathComponent("first.log")
    let secondURL = directoryURL.appendingPathComponent("second.log")

    let logger = makeQuietLogger(label: "easybar")
    logger.configureFileLogging(enabled: true, path: firstURL.path)
    logger.info("first file only")

    logger.configureFileLogging(enabled: true, path: secondURL.path)
    logger.info("second file only")

    logger.configureFileLogging(enabled: false, path: "")

    let firstOutput = try String(contentsOf: firstURL, encoding: .utf8)
    let secondOutput = try String(contentsOf: secondURL, encoding: .utf8)

    XCTAssertTrue(firstOutput.contains("first file only"))
    XCTAssertFalse(firstOutput.contains("second file only"))

    XCTAssertFalse(secondOutput.contains("first file only"))
    XCTAssertTrue(secondOutput.contains("second file only"))
  }

  /// Verifies that typed log fields escape backslashes and carriage returns.
  func testTypedLogFieldsEscapeBackslashesAndCarriageReturns() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.info(
      "escaped fields",
      .field("path", #"C:\tmp\easybar"#),
      .field("line", "one\rtwo")
    )

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(
      output.contains(#"escaped fields path=C:\\tmp\\easybar line=one\rtwo"#)
    )
  }

  /// Verifies that info omits subsystem outside debug and trace modes.
  func testInfoOmitsSubsystemOutsideDebugAndTraceModes() throws {
    let fixture = try makeLogger(label: "easybar.app.window", minimumLevel: .info)
    defer { cleanup(fixture) }

    fixture.logger.info("runtime log level changed to info")

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("] [INFO ] runtime log level changed to info"))
    XCTAssertFalse(output.contains("subsystem=easybar.app.window"))
  }

  /// Verifies that warn and error always append subsystem outside debug and trace modes.
  func testWarnAndErrorAlwaysAppendSubsystemOutsideDebugAndTraceModes() throws {
    let fixture = try makeLogger(label: "easybar.app.window", minimumLevel: .info)
    defer { cleanup(fixture) }

    fixture.logger.warn("warn event")
    fixture.logger.error("error event")

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("] [WARN ] warn event subsystem=easybar.app.window"))
    XCTAssertTrue(output.contains("] [ERROR] error event subsystem=easybar.app.window"))
  }

  /// Verifies that debug mode appends subsystem for all levels.
  func testDebugModeAppendsSubsystemForAllLevels() throws {
    let fixture = try makeLogger(label: "easybar.app.window", minimumLevel: .debug)
    defer { cleanup(fixture) }

    fixture.logger.info("info event")
    fixture.logger.debug("debug event")

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("] [INFO ] info event subsystem=easybar.app.window"))
    XCTAssertTrue(output.contains("] [DEBUG] debug event subsystem=easybar.app.window"))
  }

  /// Verifies that existing subsystem field is not duplicated.
  func testExistingSubsystemFieldIsNotDuplicated() throws {
    let fixture = try makeLogger(label: "easybar.app.window", minimumLevel: .debug)
    defer { cleanup(fixture) }

    fixture.logger.info("info event", .field("subsystem", "custom.logger"))

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("info event subsystem=custom.logger"))
    XCTAssertFalse(output.contains("subsystem=easybar.app.window"))
  }

  /// Verifies that default logging directory path uses user state directory.
  func testDefaultLoggingDirectoryPathUsesUserStateDirectory() {
    let expected = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".local/state/easybar")
      .path

    XCTAssertEqual(defaultLoggingDirectoryPath(), expected)
  }
}

extension ProcessLoggerAdditionalTests {
  /// Verifies that size-based rotation retains the configured numbered archives.
  func testFileLoggingRotatesBeforeNextLineExceedsLimit() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let fileURL = directoryURL.appendingPathComponent("rotating.log")
    let logger = makeQuietLogger(
      label: "easybar",
      rotationPolicy: ProcessLogRotationPolicy(
        maximumFileBytes: 150,
        retainedFileCount: 2
      )
    )
    logger.configureFileLogging(enabled: true, path: fileURL.path)

    for index in 1...4 {
      logger.info("rotation-message-\(index)-" + String(repeating: "x", count: 72))
    }
    logger.configureFileLogging(enabled: false, path: "")

    let active = try String(contentsOf: fileURL, encoding: .utf8)
    let firstArchive = try String(contentsOfFile: fileURL.path + ".1", encoding: .utf8)
    let secondArchive = try String(contentsOfFile: fileURL.path + ".2", encoding: .utf8)

    XCTAssertTrue(active.contains("rotation-message-4"))
    XCTAssertTrue(firstArchive.contains("rotation-message-3"))
    XCTAssertTrue(secondArchive.contains("rotation-message-2"))
    XCTAssertFalse((active + firstArchive + secondArchive).contains("rotation-message-1"))
  }

  /// Verifies that writes remain complete while file output is reconfigured concurrently.
  func testConcurrentWritesRemainCompleteDuringFileReconfiguration() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let firstURL = directoryURL.appendingPathComponent("first.log")
    let secondURL = directoryURL.appendingPathComponent("second.log")
    let logger = makeQuietLogger(
      label: "easybar",
      rotationPolicy: .disabled
    )
    logger.configureFileLogging(enabled: true, path: firstURL.path)

    let group = DispatchGroup()
    let queue = DispatchQueue(label: "process-logger-tests", attributes: .concurrent)

    for index in 0..<100 {
      group.enter()
      queue.async {
        logger.info("concurrent-message-\(index)")
        group.leave()
      }
    }

    group.enter()
    queue.async {
      for index in 0..<20 {
        let path = index.isMultiple(of: 2) ? secondURL.path : firstURL.path
        logger.configureFileLogging(enabled: true, path: path)
      }
      group.leave()
    }

    XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
    logger.configureFileLogging(enabled: false, path: "")

    let first = (try? String(contentsOf: firstURL, encoding: .utf8)) ?? ""
    let second = (try? String(contentsOf: secondURL, encoding: .utf8)) ?? ""
    let combined = first + second

    for index in 0..<100 {
      XCTAssertEqual(
        combined.components(separatedBy: "] [INFO ] concurrent-message-\(index)\n").count - 1,
        1
      )
    }
  }
}
