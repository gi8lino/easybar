import Darwin
import Foundation

/// Supported log levels ordered from least to most verbose.
public enum ProcessLogLevel: Int, CaseIterable, Sendable {
  case error = 0
  case warn = 1
  case info = 2
  case debug = 3
  case trace = 4

  /// Returns the canonical uppercase label used in log output.
  public var label: String {
    switch self {
    case .error:
      return "ERROR"
    case .warn:
      return "WARN"
    case .info:
      return "INFO"
    case .debug:
      return "DEBUG"
    case .trace:
      return "TRACE"
    }
  }

  /// Parses one user-facing level string.
  public init?(string: String) {
    switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "error":
      self = .error
    case "warn", "warning":
      self = .warn
    case "info":
      self = .info
    case "debug":
      self = .debug
    case "trace":
      self = .trace
    default:
      return nil
    }
  }
}

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
  private var minimumLevelFlag: ProcessLogLevel
  private var fileLoggingEnabledFlag = false
  private var fileLoggingPathValue = ""

  public init(label: String, minimumLevel: ProcessLogLevel = .info) {
    self.label = label
    minimumLevelFlag = minimumLevel
  }

  public var minimumLevel: ProcessLogLevel {
    lock.lock()
    defer { lock.unlock() }
    return minimumLevelFlag
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

  /// Updates the minimum enabled log level.
  public func setMinimumLevel(_ level: ProcessLogLevel) {
    lock.lock()
    minimumLevelFlag = level
    lock.unlock()
  }

  /// Configures minimum level and optional file logging in one step.
  public func configureRuntimeLogging(
    minimumLevel: ProcessLogLevel,
    fileLoggingEnabled: Bool,
    fileLoggingPath: String
  ) {
    setMinimumLevel(minimumLevel)
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
      writeUnlocked(level: .info, message: "file logging enabled path=\(url.path)", stream: stdout)
    } catch {
      fileLoggingEnabledFlag = false
      writeUnlocked(
        level: .warn,
        message: "failed to open log file at \(path): \(error)",
        stream: stderr
      )
    }
  }

  /// Writes one trace message when the minimum level allows it.
  public func trace(_ message: String) {
    writeIfEnabled(level: .trace, message: message, stream: stdout)
  }

  /// Writes one debug message when the minimum level allows it.
  public func debug(_ message: String) {
    writeIfEnabled(level: .debug, message: message, stream: stdout)
  }

  /// Writes one info message when the minimum level allows it.
  public func info(_ message: String) {
    writeIfEnabled(level: .info, message: message, stream: stdout)
  }

  /// Writes one warning message when the minimum level allows it.
  public func warn(_ message: String) {
    writeIfEnabled(level: .warn, message: message, stream: stderr)
  }

  /// Writes one error message when the minimum level allows it.
  public func error(_ message: String) {
    writeIfEnabled(level: .error, message: message, stream: stderr)
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

  private func writeIfEnabled(
    level: ProcessLogLevel,
    message: String,
    stream: UnsafeMutablePointer<FILE>?
  ) {
    lock.lock()
    defer { lock.unlock() }

    guard level.rawValue <= minimumLevelFlag.rawValue else { return }
    writeUnlocked(level: level, message: message, stream: stream)
  }

  private func writeUnlocked(
    level: ProcessLogLevel,
    message: String,
    stream: UnsafeMutablePointer<FILE>?
  ) {
    let line = formattedLine(level: level, message: message)
    fputs(line + "\n", stream)
    fflush(stream)
    writeFileUnlocked(line)
  }

  private func formattedLine(level: ProcessLogLevel, message: String) -> String {
    "[\(Self.formatter.string(from: Date()))] \(label) [\(level.label)] \(message)"
  }

  private func writeFileUnlocked(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else { return }

    do {
      try fileHandle?.write(contentsOf: data)
    } catch {
      fileLoggingEnabledFlag = false
      fputs(
        formattedLine(level: .warn, message: "failed writing log file: \(error)") + "\n",
        stderr
      )
      fflush(stderr)
      fileHandle?.closeFile()
      fileHandle = nil
    }
  }
}
