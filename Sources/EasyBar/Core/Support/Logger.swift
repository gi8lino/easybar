import EasyBarShared
import Foundation

/// Central app logger used by Swift and Lua runtime messages.
enum Logger {
  private static let shared = ProcessLogger(label: "easybar")

  static var debugEnabled: Bool {
    shared.debugEnabled
  }

  /// Configures optional mirroring of logs into one file.
  static func configureFileLogging(enabled: Bool, path: String) {
    shared.configureRuntimeLogging(
      debugEnabled: Config.shared.environmentDebugOverride() ?? Config.shared.loggingDebugEnabled,
      fileLoggingEnabled: enabled,
      fileLoggingPath: path
    )
  }

  static var fileLoggingEnabled: Bool {
    shared.fileLoggingEnabled
  }

  static var fileLoggingPath: String {
    shared.fileLoggingPath
  }

  /// Writes one debug message when debug logging is enabled.
  static func debug(_ msg: String) {
    shared.debug(msg)
  }

  /// Writes one info message.
  static func info(_ msg: String) {
    shared.info(msg)
  }

  /// Writes one warning message.
  static func warn(_ msg: String) {
    shared.warn(msg)
  }

  /// Writes one error message.
  static func error(_ msg: String) {
    shared.error(msg)
  }
}

/// Returns the EasyBar app log path inside one logging directory.
func easyBarLogPath(in directory: String) -> String {
  URL(fileURLWithPath: directory)
    .appendingPathComponent("easybar.out")
    .path
}
