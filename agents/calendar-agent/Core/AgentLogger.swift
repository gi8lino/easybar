import EasyBarShared

enum AgentLogger {
  private static let shared = ProcessLogger(label: "easybar-calendar-agent") {
    defaultDebugLoggingEnabled()
  }

  static var fileLoggingEnabled: Bool {
    defaultFileLoggingEnabled()
  }

  static var fileLoggingPath: String {
    defaultCalendarAgentLogPath()
  }

  static var debugEnabled: Bool {
    shared.debugEnabled
  }

  static func configureFileLogging(enabled: Bool, path: String) {
    shared.configureFileLogging(enabled: enabled, path: path)
  }

  static func debug(_ message: String) {
    shared.debug(message)
  }

  static func info(_ message: String) {
    shared.info(message)
  }

  static func warn(_ message: String) {
    shared.warn(message)
  }

  static func error(_ message: String) {
    shared.error(message)
  }
}
