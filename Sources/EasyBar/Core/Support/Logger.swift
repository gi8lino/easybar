import EasyBarShared
import Foundation

/// Central app logger used by Swift and Lua runtime messages.
enum Logger {
  private static let shared = ProcessLogger(label: "easybar") {
    if let override = Config.shared.environmentDebugOverride() {
      return override
    }

    return Config.shared.loggingDebugEnabled
  }

  static var debugEnabled: Bool {
    shared.debugEnabled
  }

  /// Configures optional mirroring of logs into one file.
  static func configureFileLogging(enabled: Bool, path: String) {
    shared.configureFileLogging(enabled: enabled, path: path)
  }

  static var fileLoggingEnabled: Bool {
    Config.shared.loggingEnabled
  }

  static var fileLoggingPath: String {
    easyBarLogPath(in: Config.shared.loggingDirectory)
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
