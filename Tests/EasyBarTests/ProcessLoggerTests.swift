import Foundation
import XCTest

@testable import EasyBarShared

final class ProcessLoggerTests: XCTestCase {
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
        "] easybar [INFO] network event event=wifi_change connected=true rssi=-51"
      )
    )
  }

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
    XCTAssertTrue(output.contains("] easybar [WARN] warn visible"))
    XCTAssertTrue(output.contains("] easybar [ERROR] error visible"))
  }

  func testSetMinimumLevelUpdatesRuntimeFiltering() throws {
    let fixture = try makeLogger(label: "easybar", minimumLevel: .error)
    defer { cleanup(fixture) }

    fixture.logger.debug("debug hidden")
    fixture.logger.setMinimumLevel(.debug)
    fixture.logger.debug("debug visible")

    let output = try readLogAndClose(fixture)

    XCTAssertFalse(output.contains("debug hidden"))
    XCTAssertTrue(output.contains("] easybar [DEBUG] debug visible"))
  }

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
        "] easybar.network [INFO] child event event=socket_connected"
      )
    )
  }

  func testEmptyChildLoggerSuffixReturnsParentLogger() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    let child = fixture.logger.child("  ")

    child.info("parent event")

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("] easybar [INFO] parent event"))
    XCTAssertFalse(output.contains("easybar."))
  }

  func testWriteRawMirrorsUnformattedMessageToLogFile() throws {
    let fixture = try makeLogger(label: "easybar")
    defer { cleanup(fixture) }

    fixture.logger.writeRaw("plain runtime output", to: stdout)

    let output = try readLogAndClose(fixture)

    XCTAssertTrue(output.contains("plain runtime output\n"))
    XCTAssertFalse(output.contains("[INFO] plain runtime output"))
  }

  func testRuntimeLoggingConfigurationUpdatesLevelAndFileState() throws {
    let directoryURL = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let fileURL = directoryURL.appendingPathComponent("runtime.log")
    let logger = ProcessLogger(label: "easybar")

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
    XCTAssertTrue(output.contains("] easybar [DEBUG] runtime debug"))
  }

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
        "] easybar [INFO] process startup process=easybar event=startup"
      )
    )
    XCTAssertTrue(
      output.contains(
        "] easybar [INFO] process startup config config_path=/tmp/easybar/config.toml"
      )
    )
    XCTAssertTrue(
      output.contains(
        "] easybar [INFO] process startup socket socket_path=/tmp/easybar/easybar.sock"
      )
    )
    XCTAssertTrue(
      output.contains(
        "process startup logging logging_enabled=true level=info path=\(fixture.fileURL.path)"
      )
    )
  }

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
}

private struct ProcessLoggerFixture {
  let logger: ProcessLogger
  let directoryURL: URL
  let fileURL: URL
}

private func makeLogger(
  label: String,
  minimumLevel: ProcessLogLevel = .info
) throws -> ProcessLoggerFixture {
  let directoryURL = try makeTemporaryDirectory()
  let fileURL = directoryURL.appendingPathComponent("process.log")

  let logger = ProcessLogger(label: label, minimumLevel: minimumLevel)
  logger.configureFileLogging(enabled: true, path: fileURL.path)

  return ProcessLoggerFixture(
    logger: logger,
    directoryURL: directoryURL,
    fileURL: fileURL
  )
}

private func makeTemporaryDirectory() throws -> URL {
  let directoryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("easybar-logging-tests-\(UUID().uuidString)", isDirectory: true)

  try FileManager.default.createDirectory(
    at: directoryURL,
    withIntermediateDirectories: true
  )

  return directoryURL
}

private func readLogAndClose(_ fixture: ProcessLoggerFixture) throws -> String {
  fixture.logger.configureFileLogging(enabled: false, path: "")

  return try String(contentsOf: fixture.fileURL, encoding: .utf8)
}

private func cleanup(_ fixture: ProcessLoggerFixture) {
  fixture.logger.configureFileLogging(enabled: false, path: "")
  try? FileManager.default.removeItem(at: fixture.directoryURL)
}

func testChildLoggerTrimsSuffixWhitespace() throws {
  let fixture = try makeLogger(label: "easybar")
  defer { cleanup(fixture) }

  let child = fixture.logger.child("  network  ")

  child.info("trimmed child")

  let output = try readLogAndClose(fixture)

  XCTAssertTrue(output.contains("] easybar.network [INFO] trimmed child"))
  XCTAssertFalse(output.contains("easybar.  network  "))
}

func testChildLoggerSharesMinimumLevelChanges() throws {
  let fixture = try makeLogger(label: "easybar", minimumLevel: .error)
  defer { cleanup(fixture) }

  let child = fixture.logger.child("network")

  child.info("child info hidden")
  fixture.logger.setMinimumLevel(.info)
  child.info("child info visible")

  let output = try readLogAndClose(fixture)

  XCTAssertFalse(output.contains("child info hidden"))
  XCTAssertTrue(output.contains("] easybar.network [INFO] child info visible"))
}

func testConfigureFileLoggingDisabledDoesNotCreateLogFile() throws {
  let directoryURL = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directoryURL) }

  let fileURL = directoryURL.appendingPathComponent("disabled.log")
  let logger = ProcessLogger(label: "easybar")

  logger.configureFileLogging(enabled: false, path: fileURL.path)
  logger.info("stdout only")

  XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
  XCTAssertFalse(logger.fileLoggingEnabled)
  XCTAssertEqual(logger.fileLoggingPath, fileURL.path)
}

func testConfigureFileLoggingWithEmptyPathDoesNotCreateFileHandle() {
  let logger = ProcessLogger(label: "easybar")

  logger.configureFileLogging(enabled: true, path: "")
  logger.info("stdout only")

  XCTAssertTrue(logger.fileLoggingEnabled)
  XCTAssertEqual(logger.fileLoggingPath, "")
}

func testReconfiguringFileLoggingMovesOutputToNewFile() throws {
  let directoryURL = try makeTemporaryDirectory()
  defer { try? FileManager.default.removeItem(at: directoryURL) }

  let firstURL = directoryURL.appendingPathComponent("first.log")
  let secondURL = directoryURL.appendingPathComponent("second.log")

  let logger = ProcessLogger(label: "easybar")
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

func testDefaultLoggingDirectoryPathUsesUserStateDirectory() {
  let expected = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/easybar")
    .path

  XCTAssertEqual(defaultLoggingDirectoryPath(), expected)
}
