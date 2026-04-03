import Darwin
import Foundation

/// Shared process logger with consistent formatting across app, agents, and CLI.
public final class ProcessLogger {
  private static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
  }()

  private let label: String
  private let debugEnabledProvider: () -> Bool
  private let lock = NSLock()
  private var fileHandle: FileHandle?

  public init(label: String, debugEnabled: @escaping () -> Bool = { false }) {
    self.label = label
    debugEnabledProvider = debugEnabled
  }

  public var debugEnabled: Bool {
    debugEnabledProvider()
  }

  /// Configures optional mirroring of log lines into one file.
  public func configureFileLogging(enabled: Bool, path: String) {
    lock.lock()
    defer { lock.unlock() }

    fileHandle?.closeFile()
    fileHandle = nil

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
      writeUnlocked(
        level: "WARN",
        message: "failed to open log file at \(path): \(error)",
        stream: stderr
      )
    }
  }

  /// Writes one debug message when debug logging is enabled.
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

  /// Writes one message without timestamped logger formatting.
  public func writeRaw(_ message: String, to stream: UnsafeMutablePointer<FILE>?) {
    lock.lock()
    defer { lock.unlock() }
    fputs(message + "\n", stream)
    fflush(stream)
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
