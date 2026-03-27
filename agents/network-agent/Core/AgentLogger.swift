import EasyBarShared

enum AgentLogger {
  private static let shared = ProcessLogger(label: "easybar-network-agent") {
    defaultDebugLoggingEnabled()
  }

  static var debugEnabled: Bool {
    shared.debugEnabled
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
