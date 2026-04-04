import EasyBarShared

enum AgentLogger {
  private static var debugFlag = false
  private(set) static var fileLoggingEnabled = false
  private(set) static var fileLoggingPath = ""

  private static let shared = ProcessLogger(label: "easybar-calendar-agent") {
    debugFlag
  }

  /// Configures debug and file logging from runtime config.
  static func configure(using config: SharedRuntimeConfig) {
    debugFlag = config.loggingDebugEnabled
    fileLoggingEnabled = config.loggingEnabled
    fileLoggingPath = calendarAgentLogPath(in: config.loggingDirectory)
    shared.configureFileLogging(enabled: fileLoggingEnabled, path: fileLoggingPath)
  }

  /// Returns whether debug logging is currently enabled.
  static var debugEnabled: Bool {
    shared.debugEnabled
  }

  /// Writes one debug log line.
  static func debug(_ message: String) {
    shared.debug(message)
  }

  /// Writes one info log line.
  static func info(_ message: String) {
    shared.info(message)
  }

  /// Writes one warning log line.
  static func warn(_ message: String) {
    shared.warn(message)
  }

  /// Writes one error log line.
  static func error(_ message: String) {
    shared.error(message)
  }
}
