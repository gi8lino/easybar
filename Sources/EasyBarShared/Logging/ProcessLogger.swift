import Darwin
import Foundation

/// One structured field attached to a process log entry.
public struct ProcessLogField {
  public let key: String
  public let value: Any?

  public init(_ key: String, _ value: Any?) {
    self.key = key
    self.value = value
  }

  /// Builds one typed process log field for contextual `.field(...)` call sites.
  public static func field(_ key: String, _ value: Any?) -> ProcessLogField {
    ProcessLogField(key, value)
  }
}

/// Formats typed log fields into one compact string.
private func formatLogFields(_ fields: [ProcessLogField]) -> String {
  guard !fields.isEmpty else { return "" }

  return
    fields
    .map { "\($0.key)=\(formatLogFieldValue($0.value))" }
    .joined(separator: " ")
}

/// Formats one log field value.
private func formatLogFieldValue(_ value: Any?) -> String {
  guard let value else { return "nil" }

  let text = String(describing: value)
  let escaped =
    text
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\n", with: "\\n")
    .replacingOccurrences(of: "\r", with: "\\r")
    .replacingOccurrences(of: "\t", with: "\\t")
    .replacingOccurrences(of: "\"", with: "\\\"")

  guard escaped.contains(where: \.isWhitespace) || escaped.isEmpty else {
    return escaped
  }

  return "\"\(escaped)\""
}

/// Shared process logger with consistent formatting across app, agents, and CLI.
public final class ProcessLogger {
  /// Shared mutable logger state.
  private final class SharedState {
    let lock = NSLock()
    var fileHandle: FileHandle?
    var minimumLevel: ProcessLogLevel
    var fileLoggingEnabled = false
    var fileLoggingPath = ""

    /// Creates shared logger state.
    init(minimumLevel: ProcessLogLevel) {
      self.minimumLevel = minimumLevel
    }
  }

  /// Formats log timestamps.
  private static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    return formatter
  }()

  private let label: String
  private let sharedState: SharedState

  /// Creates one process logger.
  public init(label: String, minimumLevel: ProcessLogLevel = .info) {
    self.label = label
    sharedState = SharedState(minimumLevel: minimumLevel)
  }

  /// Creates one child logger with shared state.
  private init(label: String, sharedState: SharedState) {
    self.label = label
    self.sharedState = sharedState
  }

  /// Returns one child logger that shares runtime configuration and file output.
  public func child(_ suffix: String) -> ProcessLogger {
    let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedSuffix.isEmpty else { return self }

    return ProcessLogger(label: "\(label).\(trimmedSuffix)", sharedState: sharedState)
  }

  /// Current minimum log level.
  public var minimumLevel: ProcessLogLevel {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    return sharedState.minimumLevel
  }

  /// Whether file logging is enabled.
  public var fileLoggingEnabled: Bool {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    return sharedState.fileLoggingEnabled
  }

  /// Current file logging path.
  public var fileLoggingPath: String {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    return sharedState.fileLoggingPath
  }

  /// Updates the current minimum log level.
  public func setMinimumLevel(_ level: ProcessLogLevel) {
    sharedState.lock.lock()
    sharedState.minimumLevel = level
    sharedState.lock.unlock()
  }

  /// Configures minimum level and optional file logging.
  public func configureRuntimeLogging(
    minimumLevel: ProcessLogLevel,
    fileLoggingEnabled: Bool,
    fileLoggingPath: String
  ) {
    setMinimumLevel(minimumLevel)
    configureFileLogging(enabled: fileLoggingEnabled, path: fileLoggingPath)
  }

  /// Configures optional mirroring into one file.
  public func configureFileLogging(enabled: Bool, path: String) {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    sharedState.fileHandle?.closeFile()
    sharedState.fileHandle = nil
    sharedState.fileLoggingEnabled = enabled
    sharedState.fileLoggingPath = path

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
      sharedState.fileHandle = handle
    } catch {
      sharedState.fileLoggingEnabled = false
      writeUnlocked(
        level: "WARN",
        message: "failed to open log file at \(path): \(error)",
        stream: stderr
      )
    }
  }

  /// Writes one trace message.
  public func trace(_ message: String) {
    guard shouldLog(.trace) else { return }

    write(level: "TRACE", message: message, stream: stdout)
  }

  /// Writes one trace message with typed fields.
  public func trace(_ message: String, _ fields: ProcessLogField...) {
    trace(combine(message: message, fields: fields))
  }

  /// Writes one debug message.
  public func debug(_ message: String) {
    guard shouldLog(.debug) else { return }

    write(level: "DEBUG", message: message, stream: stdout)
  }

  /// Writes one debug message with typed fields.
  public func debug(_ message: String, _ fields: ProcessLogField...) {
    debug(combine(message: message, fields: fields))
  }

  /// Writes one info message.
  public func info(_ message: String) {
    guard shouldLog(.info) else { return }

    write(level: "INFO", message: message, stream: stdout)
  }

  /// Writes one info message with typed fields.
  public func info(_ message: String, _ fields: ProcessLogField...) {
    info(combine(message: message, fields: fields))
  }

  /// Writes one warning message.
  public func warn(_ message: String) {
    guard shouldLog(.warn) else { return }

    write(level: "WARN", message: message, stream: stderr)
  }

  /// Writes one warning message with typed fields.
  public func warn(_ message: String, _ fields: ProcessLogField...) {
    warn(combine(message: message, fields: fields))
  }

  /// Writes one error message.
  public func error(_ message: String) {
    guard shouldLog(.error) else { return }

    write(level: "ERROR", message: message, stream: stderr)
  }

  /// Writes one error message with typed fields.
  public func error(_ message: String, _ fields: ProcessLogField...) {
    error(combine(message: message, fields: fields))
  }

  /// Writes one raw message and mirrors it to the log file.
  public func writeRaw(_ message: String, to stream: UnsafeMutablePointer<FILE>?) {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    fputs(message + "\n", stream)
    fflush(stream)
    writeFileUnlocked(message)
  }

  /// Returns whether one level should be logged.
  private func shouldLog(_ level: ProcessLogLevel) -> Bool {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    return sharedState.minimumLevel.allows(level)
  }

  /// Writes one formatted message.
  private func write(level: String, message: String, stream: UnsafeMutablePointer<FILE>?) {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    writeUnlocked(level: level, message: message, stream: stream)
  }

  /// Writes one formatted message while locked.
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

  /// Builds one formatted log line.
  private func formattedLine(level: String, message: String) -> String {
    "[\(Self.formatter.string(from: Date()))] \(label) [\(level)] \(message)"
  }

  /// Appends typed fields to one message.
  private func combine(message: String, fields: [ProcessLogField]) -> String {
    let rendered = formatLogFields(fields)
    guard !rendered.isEmpty else { return message }

    return "\(message) \(rendered)"
  }

  /// Writes one line to the configured log file.
  private func writeFileUnlocked(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else { return }

    do {
      try sharedState.fileHandle?.write(contentsOf: data)
    } catch {
      sharedState.fileLoggingEnabled = false
      fputs(
        formattedLine(level: "WARN", message: "failed writing log file: \(error)") + "\n",
        stderr
      )
      fflush(stderr)
      sharedState.fileHandle?.closeFile()
      sharedState.fileHandle = nil
    }
  }
}
