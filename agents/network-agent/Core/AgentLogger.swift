import EasyBarShared

enum AgentLogger {
  private static var debugFlag = false
  private(set) static var fileLoggingEnabled = false
  private(set) static var fileLoggingPath = ""

  private static let shared = ProcessLogger(label: "easybar-network-agent") {
    debugFlag
  }

  static func configure(using config: SharedRuntimeConfig) {
    debugFlag = config.loggingDebugEnabled
    fileLoggingEnabled = config.loggingEnabled
    fileLoggingPath = networkAgentLogPath(in: config.loggingDirectory)
    shared.configureFileLogging(enabled: fileLoggingEnabled, path: fileLoggingPath)
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
