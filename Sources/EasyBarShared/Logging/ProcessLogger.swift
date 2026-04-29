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

/// Formats alternating key/value components into one compact single-line log field string.
public func formatLogFields(_ components: Any?...) -> String {
  formatLogFields(components)
}

/// Formats typed log fields into one compact single-line string.
public func formatLogFields(_ fields: ProcessLogField...) -> String {
  formatLogFields(fields)
}

private func formatLogFields(_ components: [Any?]) -> String {
  guard !components.isEmpty else { return "" }

  var fields: [String] = []
  fields.reserveCapacity(components.count / 2)

  var index = 0
  while index < components.count {
    let key = String(describing: components[index] ?? "nil")
    let value = index + 1 < components.count ? components[index + 1] : nil
    fields.append("\(key)=\(formatLogFieldValue(value))")
    index += 2
  }

  return fields.joined(separator: " ")
}

private func formatLogFields(_ fields: [ProcessLogField]) -> String {
  guard !fields.isEmpty else { return "" }

  return fields
    .map { "\($0.key)=\(formatLogFieldValue($0.value))" }
    .joined(separator: " ")
}

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
  private final class SharedState {
    let lock = NSLock()
    var fileHandle: FileHandle?
    var minimumLevel: ProcessLogLevel
    var fileLoggingEnabled = false
    var fileLoggingPath = ""

    init(minimumLevel: ProcessLogLevel) {
      self.minimumLevel = minimumLevel
    }
  }

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

  public init(label: String, minimumLevel: ProcessLogLevel = .info) {
    self.label = label
    sharedState = SharedState(minimumLevel: minimumLevel)
  }

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

  public var minimumLevel: ProcessLogLevel {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }
    return sharedState.minimumLevel
  }

  public var fileLoggingEnabled: Bool {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }
    return sharedState.fileLoggingEnabled
  }

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

  /// Writes one trace message when trace logging is enabled.
  public func trace(_ message: String) {
    guard shouldLog(.trace) else { return }
    write(level: "TRACE", message: message, stream: stdout)
  }

  /// Writes one trace message with structured fields when trace logging is enabled.
  public func trace(_ message: String, _ components: Any?...) {
    trace(combine(message: message, components: components))
  }

  /// Writes one trace message with typed structured fields when trace logging is enabled.
  public func trace(_ message: String, _ fields: ProcessLogField...) {
    trace(combine(message: message, fields: fields))
  }

  /// Writes one debug message when debug or trace logging is enabled.
  public func debug(_ message: String) {
    guard shouldLog(.debug) else { return }
    write(level: "DEBUG", message: message, stream: stdout)
  }

  /// Writes one debug message with structured fields when debug or trace logging is enabled.
  public func debug(_ message: String, _ components: Any?...) {
    debug(combine(message: message, components: components))
  }

  /// Writes one debug message with typed structured fields when debug or trace logging is enabled.
  public func debug(_ message: String, _ fields: ProcessLogField...) {
    debug(combine(message: message, fields: fields))
  }

  /// Writes one info message.
  public func info(_ message: String) {
    guard shouldLog(.info) else { return }
    write(level: "INFO", message: message, stream: stdout)
  }

  /// Writes one info message with structured fields.
  public func info(_ message: String, _ components: Any?...) {
    info(combine(message: message, components: components))
  }

  /// Writes one info message with typed structured fields.
  public func info(_ message: String, _ fields: ProcessLogField...) {
    info(combine(message: message, fields: fields))
  }

  /// Writes one warning message.
  public func warn(_ message: String) {
    guard shouldLog(.warn) else { return }
    write(level: "WARN", message: message, stream: stderr)
  }

  /// Writes one warning message with structured fields.
  public func warn(_ message: String, _ components: Any?...) {
    warn(combine(message: message, components: components))
  }

  /// Writes one warning message with typed structured fields.
  public func warn(_ message: String, _ fields: ProcessLogField...) {
    warn(combine(message: message, fields: fields))
  }

  /// Writes one error message.
  public func error(_ message: String) {
    guard shouldLog(.error) else { return }
    write(level: "ERROR", message: message, stream: stderr)
  }

  /// Writes one error message with structured fields.
  public func error(_ message: String, _ components: Any?...) {
    error(combine(message: message, components: components))
  }

  /// Writes one error message with typed structured fields.
  public func error(_ message: String, _ fields: ProcessLogField...) {
    error(combine(message: message, fields: fields))
  }

  /// Writes one message without timestamped logger formatting and mirrors it to the log file when enabled.
  public func writeRaw(_ message: String, to stream: UnsafeMutablePointer<FILE>?) {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }

    let line = message + "\n"
    fputs(line, stream)
    fflush(stream)
    writeFileUnlocked(message)
  }

  private func shouldLog(_ level: ProcessLogLevel) -> Bool {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }
    return sharedState.minimumLevel.allows(level)
  }

  private func write(level: String, message: String, stream: UnsafeMutablePointer<FILE>?) {
    sharedState.lock.lock()
    defer { sharedState.lock.unlock() }
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

  private func combine(message: String, components: [Any?]) -> String {
    let fields = combinedFields(from: components)
    guard !fields.isEmpty else { return message }
    return "\(message) \(fields)"
  }

  private func combine(message: String, fields: [ProcessLogField]) -> String {
    let rendered = formatLogFields(fields)
    guard !rendered.isEmpty else { return message }
    return "\(message) \(rendered)"
  }

  private func combinedFields(from components: [Any?]) -> String {
    guard !components.isEmpty else { return "" }

    if components.count == 1, let preformatted = components[0] as? String {
      return preformatted
    }

    return formatLogFields(components)
  }

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
