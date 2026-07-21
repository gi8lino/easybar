import Darwin
import Dispatch
import Foundation

/// Returns the default log directory used by EasyBar processes.
public func defaultLoggingDirectoryPath() -> String {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".local/state/easybar")
    .path
}

/// One structured field attached to a process log entry.
public struct ProcessLogField {
  public let key: String
  public let value: Any?

  /// Creates one structured log field.
  public init(_ key: String, _ value: Any?) {
    self.key = key
    self.value = value
  }

  /// Builds one typed process log field for contextual `.field(...)` call sites.
  public static func field(_ key: String, _ value: Any?) -> ProcessLogField {
    ProcessLogField(key, value)
  }
}

/// Size-based file rotation applied by one process logger.
public struct ProcessLogRotationPolicy: Equatable, Sendable {
  /// Maximum active log-file size before the next line rotates it.
  public let maximumFileBytes: Int
  /// Number of numbered archives retained beside the active log file.
  public let retainedFileCount: Int

  /// Creates one normalized rotation policy.
  public init(maximumFileBytes: Int, retainedFileCount: Int) {
    self.maximumFileBytes = max(0, maximumFileBytes)
    self.retainedFileCount = max(0, retainedFileCount)
  }

  /// Default protection for long-running EasyBar process logs.
  public static let `default` = ProcessLogRotationPolicy(
    maximumFileBytes: 10 * 1_024 * 1_024,
    retainedFileCount: 3
  )

  /// Disables size-based file rotation.
  public static let disabled = ProcessLogRotationPolicy(
    maximumFileBytes: 0,
    retainedFileCount: 0
  )
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

extension Array where Element == ProcessLogField {
  /// Returns whether one structured field already exists for the given key.
  fileprivate func containsField(named key: String) -> Bool {
    contains { $0.key == key }
  }
}

/// Shared process logger with consistent formatting across app, agents, and CLI.
///
/// Configuration is protected by `LockedState`. All stream and file operations
/// are serialized on a dedicated output queue, so slow I/O never holds the
/// configuration lock and child loggers preserve one global write order.
public final class ProcessLogger: @unchecked Sendable {
  /// Reserved field keys managed by the logger itself.
  private enum ReservedFieldKey {
    static let subsystem = "subsystem"
  }

  /// Runtime configuration read by producers without performing I/O.
  private struct LoggerConfiguration {
    var minimumLevel: ProcessLogLevel
    var fileLoggingEnabled = false
    var fileLoggingPath = ""
  }

  /// Shared mutable state for one root logger and all child loggers.
  private final class SharedState: @unchecked Sendable {
    let configuration: LockedState<LoggerConfiguration>
    let outputQueue = DispatchQueue(label: "easybar.process-logger.output")
    let outputStream: UnsafeMutablePointer<FILE>?
    let errorStream: UnsafeMutablePointer<FILE>?
    let rotationPolicy: ProcessLogRotationPolicy

    /// Accessed only from `outputQueue`.
    var fileHandle: FileHandle?
    /// Accessed only from `outputQueue`.
    var fileByteCount = 0

    init(
      minimumLevel: ProcessLogLevel,
      outputStream: UnsafeMutablePointer<FILE>?,
      errorStream: UnsafeMutablePointer<FILE>?,
      rotationPolicy: ProcessLogRotationPolicy
    ) {
      configuration = LockedState(LoggerConfiguration(minimumLevel: minimumLevel))
      self.outputStream = outputStream
      self.errorStream = errorStream
      self.rotationPolicy = rotationPolicy
    }
  }

  /// Formats log timestamps.
  private static let formatter = LockedState<DateFormatter>(
    {
      let formatter = DateFormatter()
      formatter.calendar = Calendar(identifier: .iso8601)
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone.current
      formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
      return formatter
    }()
  )

  private let label: String
  private let sharedState: SharedState

  /// Creates one process logger.
  public init(
    label: String,
    minimumLevel: ProcessLogLevel = .info,
    outputStream: UnsafeMutablePointer<FILE>? = stdout,
    errorStream: UnsafeMutablePointer<FILE>? = stderr,
    rotationPolicy: ProcessLogRotationPolicy = .default
  ) {
    self.label = label
    sharedState = SharedState(
      minimumLevel: minimumLevel,
      outputStream: outputStream,
      errorStream: errorStream,
      rotationPolicy: rotationPolicy
    )
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
    sharedState.configuration.withLock { $0.minimumLevel }
  }

  /// Whether file logging is enabled.
  public var fileLoggingEnabled: Bool {
    sharedState.configuration.withLock { $0.fileLoggingEnabled }
  }

  /// Current file logging path.
  public var fileLoggingPath: String {
    sharedState.configuration.withLock { $0.fileLoggingPath }
  }

  /// Updates the current minimum log level.
  public func setMinimumLevel(_ level: ProcessLogLevel) {
    sharedState.configuration.withLock { state in
      state.minimumLevel = level
    }
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
    var warning: String?

    sharedState.outputQueue.sync {
      closeFileOutput()

      var effectiveEnabled = enabled
      if enabled, !path.isEmpty {
        do {
          try openFileOutput(at: path)
        } catch {
          effectiveEnabled = false
          warning = "failed to open log file at \(path): \(error)"
        }
      }

      sharedState.configuration.withLock { state in
        state.fileLoggingEnabled = effectiveEnabled
        state.fileLoggingPath = path
      }
    }

    if let warning {
      write(level: .warn, message: warning, fields: [])
    }
  }

  /// Writes one trace message.
  public func trace(_ message: String) {
    log(level: .trace, message: message, fields: [])
  }

  /// Writes one trace message with typed fields.
  public func trace(_ message: String, _ fields: ProcessLogField...) {
    log(level: .trace, message: message, fields: fields)
  }

  /// Writes one debug message.
  public func debug(_ message: String) {
    log(level: .debug, message: message, fields: [])
  }

  /// Writes one debug message with typed fields.
  public func debug(_ message: String, _ fields: ProcessLogField...) {
    log(level: .debug, message: message, fields: fields)
  }

  /// Writes one info message.
  public func info(_ message: String) {
    log(level: .info, message: message, fields: [])
  }

  /// Writes one info message with typed fields.
  public func info(_ message: String, _ fields: ProcessLogField...) {
    log(level: .info, message: message, fields: fields)
  }

  /// Writes one warning message.
  public func warn(_ message: String) {
    log(level: .warn, message: message, fields: [])
  }

  /// Writes one warning message with typed fields.
  public func warn(_ message: String, _ fields: ProcessLogField...) {
    log(level: .warn, message: message, fields: fields)
  }

  /// Writes one error message.
  public func error(_ message: String) {
    log(level: .error, message: message, fields: [])
  }

  /// Writes one error message with typed fields.
  public func error(_ message: String, _ fields: ProcessLogField...) {
    log(level: .error, message: message, fields: fields)
  }

  /// Writes one raw message and mirrors it to the log file.
  public func writeRaw(_ message: String, to stream: UnsafeMutablePointer<FILE>?) {
    sharedState.outputQueue.sync {
      if let stream {
        fputs(message + "\n", stream)
        fflush(stream)
      }
      writeFileLine(message)
    }
  }

  /// Filters and formats one typed message before serial output.
  private func log(
    level: ProcessLogLevel,
    message: String,
    fields: [ProcessLogField]
  ) {
    let minimumLevel = sharedState.configuration.withLock { $0.minimumLevel }
    guard minimumLevel.allows(level) else { return }

    let line = formattedLine(
      level: level,
      message: message,
      fields: fields,
      minimumLevel: minimumLevel
    )
    writeFormattedLine(line, level: level)
  }

  /// Writes one formatted message without holding the configuration lock.
  private func write(
    level: ProcessLogLevel,
    message: String,
    fields: [ProcessLogField]
  ) {
    let minimumLevel = sharedState.configuration.withLock { $0.minimumLevel }
    let line = formattedLine(
      level: level,
      message: message,
      fields: fields,
      minimumLevel: minimumLevel
    )
    writeFormattedLine(line, level: level)
  }

  /// Serializes stream output and file mirroring for one formatted line.
  private func writeFormattedLine(_ line: String, level: ProcessLogLevel) {
    sharedState.outputQueue.sync {
      if let stream = outputStream(for: level) {
        fputs(line + "\n", stream)
        fflush(stream)
      }
      writeFileLine(line)
    }
  }

  /// Selects the configured process stream for one log level.
  private func outputStream(for level: ProcessLogLevel) -> UnsafeMutablePointer<FILE>? {
    switch level {
    case .trace, .debug, .info:
      return sharedState.outputStream
    case .warn, .error:
      return sharedState.errorStream
    }
  }

  /// Builds one formatted log line.
  private func formattedLine(
    level: ProcessLogLevel,
    message: String,
    fields: [ProcessLogField],
    minimumLevel: ProcessLogLevel
  ) -> String {
    let renderedLevel = level.formattedTag
    let renderedMessage = renderedMessage(
      level: level,
      message: message,
      fields: fields,
      minimumLevel: minimumLevel
    )
    return "[\(Self.formatTimestamp(Date()))] [\(renderedLevel)] \(renderedMessage)"
  }

  /// Formats one timestamp through the locked shared formatter.
  private static func formatTimestamp(_ date: Date) -> String {
    formatter.withLock { formatter in
      formatter.string(from: date)
    }
  }

  /// Adds subsystem context only when the active runtime mode or severity requires it.
  private func renderedMessage(
    level: ProcessLogLevel,
    message: String,
    fields: [ProcessLogField],
    minimumLevel: ProcessLogLevel
  ) -> String {
    let renderedFields = renderedFields(
      level: level,
      fields: fields,
      minimumLevel: minimumLevel
    )
    guard !renderedFields.isEmpty else { return message }

    return "\(message) \(renderedFields)"
  }

  /// Returns whether the current mode should append subsystem details.
  private func shouldAppendSubsystem(
    for level: ProcessLogLevel,
    minimumLevel: ProcessLogLevel
  ) -> Bool {
    if minimumLevel == .debug || minimumLevel == .trace {
      return true
    }

    return level == .warn || level == .error
  }

  /// Renders caller-provided fields plus logger-managed metadata.
  private func renderedFields(
    level: ProcessLogLevel,
    fields: [ProcessLogField],
    minimumLevel: ProcessLogLevel
  ) -> String {
    let metadataFields = metadataFields(
      for: level,
      existingFields: fields,
      minimumLevel: minimumLevel
    )
    return formatLogFields(fields + metadataFields)
  }

  /// Builds logger-managed metadata fields for the current line.
  private func metadataFields(
    for level: ProcessLogLevel,
    existingFields: [ProcessLogField],
    minimumLevel: ProcessLogLevel
  ) -> [ProcessLogField] {
    guard shouldAppendSubsystem(for: level, minimumLevel: minimumLevel) else { return [] }
    guard !existingFields.containsField(named: ReservedFieldKey.subsystem) else {
      return []
    }

    return [.field(ReservedFieldKey.subsystem, label)]
  }

  /// Writes one line to the configured log file and rotates it before overflow.
  private func writeFileLine(_ line: String) {
    guard let data = (line + "\n").data(using: .utf8) else { return }
    guard sharedState.fileHandle != nil else { return }

    do {
      try rotateFileIfNeeded(additionalBytes: data.count)
      try sharedState.fileHandle?.write(contentsOf: data)
      sharedState.fileByteCount += data.count
    } catch {
      disableFileOutputAfterFailure(error)
    }
  }

  /// Rotates numbered archives when the next line would exceed the active-file limit.
  private func rotateFileIfNeeded(additionalBytes: Int) throws {
    let policy = sharedState.rotationPolicy
    guard policy.maximumFileBytes > 0 else { return }
    guard sharedState.fileByteCount > 0 else { return }
    guard sharedState.fileByteCount + additionalBytes > policy.maximumFileBytes else { return }

    let path = sharedState.configuration.withLock { $0.fileLoggingPath }
    guard !path.isEmpty else { return }

    closeFileOutput()
    try rotateFiles(at: path, retainedFileCount: policy.retainedFileCount)
    try openFileOutput(at: path)
  }

  /// Moves the active file through `.1`, `.2`, and later archives.
  private func rotateFiles(at path: String, retainedFileCount: Int) throws {
    let fileManager = FileManager.default
    let activeURL = URL(fileURLWithPath: path)

    guard retainedFileCount > 0 else {
      if fileManager.fileExists(atPath: path) {
        try fileManager.removeItem(at: activeURL)
      }
      return
    }

    let lastArchiveURL = URL(fileURLWithPath: "\(path).\(retainedFileCount)")
    if fileManager.fileExists(atPath: lastArchiveURL.path) {
      try fileManager.removeItem(at: lastArchiveURL)
    }

    if retainedFileCount > 1 {
      for index in stride(from: retainedFileCount - 1, through: 1, by: -1) {
        let sourceURL = URL(fileURLWithPath: "\(path).\(index)")
        guard fileManager.fileExists(atPath: sourceURL.path) else { continue }
        let destinationURL = URL(fileURLWithPath: "\(path).\(index + 1)")
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
      }
    }

    if fileManager.fileExists(atPath: path) {
      try fileManager.moveItem(
        at: activeURL,
        to: URL(fileURLWithPath: "\(path).1")
      )
    }
  }

  /// Opens one append-only file output and records its existing size.
  private func openFileOutput(at path: String) throws {
    let url = URL(fileURLWithPath: path)
    let directoryURL = url.deletingLastPathComponent()

    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    if !FileManager.default.fileExists(atPath: url.path) {
      guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
        throw CocoaError(.fileWriteUnknown)
      }
    }

    let handle = try FileHandle(forWritingTo: url)
    let offset = try handle.seekToEnd()
    sharedState.fileHandle = handle
    sharedState.fileByteCount = Int(clamping: offset)
  }

  /// Closes the current file output. Call only from the serial output queue.
  private func closeFileOutput() {
    sharedState.fileHandle?.closeFile()
    sharedState.fileHandle = nil
    sharedState.fileByteCount = 0
  }

  /// Disables file output after one write or rotation failure.
  private func disableFileOutputAfterFailure(_ error: Error) {
    sharedState.configuration.withLock { state in
      state.fileLoggingEnabled = false
    }
    closeFileOutput()

    let minimumLevel = sharedState.configuration.withLock { $0.minimumLevel }
    fputs(
      formattedLine(
        level: .warn,
        message: "failed writing log file: \(error)",
        fields: [],
        minimumLevel: minimumLevel
      ) + "\n",
      stderr
    )
    fflush(stderr)
  }
}
