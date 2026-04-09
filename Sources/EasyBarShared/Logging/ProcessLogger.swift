import Darwin
import Foundation

/// Shared process logger with consistent formatting across app, agents, and CLI.
public final class ProcessLogger {
  private static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    return formatter
  }()

  private let label: String
  private let lock = NSLock()
  private var fileHandle: FileHandle?
  private var debugEnabledFlag: Bool
  private var traceEnabledFlag: Bool
  private var fileLoggingEnabledFlag = false
  private var fileLoggingPathValue = ""

  public init(label: String, debugEnabled: Bool = false, traceEnabled: Bool = false) {
    self.label = label
    debugEnabledFlag = debugEnabled
    traceEnabledFlag = traceEnabled
  }

  public var debugEnabled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return debugEnabledFlag || traceEnabledFlag
  }

  public var traceEnabled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return traceEnabledFlag
  }

  public var fileLoggingEnabled: Bool {
    lock.lock()
    defer { lock.unlock() }
    return fileLoggingEnabledFlag
  }

  public var fileLoggingPath: String {
    lock.lock()
    defer { lock.unlock() }
    return fileLoggingPathValue
  }

  /// Updates the current debug logging flag.
  public func setDebugEnabled(_ enabled: Bool) {
    lock.lock()
    debugEnabledFlag = enabled
    lock.unlock()
  }

  /// Updates the current trace logging flag.
  public func setTraceEnabled(_ enabled: Bool) {
    lock.lock()
    traceEnabledFlag = enabled
    lock.unlock()
  }

  /// Configures debug, trace, and optional file logging in one step.
  public func configureRuntimeLogging(
    debugEnabled: Bool,
    traceEnabled: Bool,
    fileLoggingEnabled: Bool,
    fileLoggingPath: String
  ) {
    setDebugEnabled(debugEnabled)
    setTraceEnabled(traceEnabled)
    configureFileLogging(enabled: fileLoggingEnabled, path: fileLoggingPath)
  }

  /// Configures optional mirroring of log lines into one file.
  public func configureFileLogging(enabled: Bool, path: String) {
    lock.lock()
    defer { lock.unlock() }

    fileHandle?.closeFile()
    fileHandle = nil
    fileLoggingEnabledFlag = enabled
    fileLoggingPathValue = path

    guard enabled, !path.isEmpty else { return }

    let url = URL(fileURLWithPath: path)
    let directoryURL = url.deletingLastPathComponent()

    do {
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )

      if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
      }

      let handle = try FileHandle(forWritingTo: url)
      try handle.seekToEnd()
      fileHandle = handle
      writeUnlocked(level: "INFO", message: "file logging enabled path=\(url.path)", stream: stdout)
    } catch {
      fileLoggingEnabledFlag = false
      writeUnlocked(
        level: "WARN",
        message: "failed to open log file at \(path): \(error)",
        stream: stderr
      )
    }
  }

  /// Writes one trace message when trace logging is enabled.
  public func trace(_ message: String) {
    guard traceEnabled else { return }
    write(level: "TRACE", message: message, stream: stdout)
  }

  /// Writes one debug message when debug or trace logging is enabled.
  public func debug(_ message: String) {
    guard debugEnabled else { return }
    write(level: "DEBUG", message: message, stream: stdout)
  }

  /// Writes one info message.
  public func info(_ message: String) {
    write(level: "INFO", message: message, stream: stdout)
  }

  /// Writes one warning message.
  public func warn(_ message: String) {
    write(level: "WARN", message: message, stream: stderr)
  }

  /// Writes one error message.
  public func error(_ message: String) {
    write(level: "ERROR", message: message, stream: stderr)
  }

  /// Writes one message without timestamped logger formatting and mirrors it to the log file when enabled.
  public func writeRaw(_ message: String, to stream: UnsafeMutablePointer<FILE>?) {
    lock.lock()
    defer { lock.unlock() }

    let line = message + "\n"
    fputs(line, stream)
    fflush(stream)
    writeFileUnlocked(message)
  }

  private func write(level: String, message: String, stream: UnsafeMutablePointer<FILE>?) {
    lock.lock()
    defer { lock.unlock() }
    writeUnlocked(level: level, message: message, stream: stream)
  }

  private func writeUnlocked(
    level: String,
    message: String,
    stream: UnsafeMutablePointer<FILE>?
  ) {
    let line = formattedLine(level: level, message: message)
    fputs(line + "\n", stream)
    fflush(stream)
    writeFileUnlocked(line)
  }

  private func formattedLine(level: String, message: String) -> String {
    "[\(Self.formatter.string(from: Date()))] \(label) [\(level)] \(message)"
  }

  private func writeFileUnlocked(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else { return }

    do {
      try fileHandle?.write(contentsOf: data)
    } catch {
      fileLoggingEnabledFlag = false
      fputs(
        formattedLine(level: "WARN", message: "failed writing log file: \(error)") + "\n",
        stderr
      )
      fflush(stderr)
      fileHandle?.closeFile()
      fileHandle = nil
    }
  }
}
