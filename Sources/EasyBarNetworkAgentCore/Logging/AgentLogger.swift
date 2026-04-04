import EasyBarShared

public enum AgentLogger {
  private static var debugFlag = false
  public private(set) static var fileLoggingEnabled = false
  public private(set) static var fileLoggingPath = ""

  private static let shared = ProcessLogger(label: "easybar-network-agent") {
    debugFlag
  }

  /// Configures debug and file logging from runtime config.
  public static func configure(using config: SharedRuntimeConfig) {
    debugFlag = config.loggingDebugEnabled
    fileLoggingEnabled = config.loggingEnabled
    fileLoggingPath = networkAgentLogPath(in: config.loggingDirectory)
    shared.configureFileLogging(enabled: fileLoggingEnabled, path: fileLoggingPath)
  }

  /// Returns whether debug logging is currently enabled.
  public static var debugEnabled: Bool {
    shared.debugEnabled
  }

  /// Writes one debug log line.
  public static func debug(_ message: String) {
    shared.debug(message)
  }

  /// Writes one info log line.
  public static func info(_ message: String) {
    shared.info(message)
  }

  /// Writes one warning log line.
  public static func warn(_ message: String) {
    shared.warn(message)
  }

  /// Writes one error log line.
  public static func error(_ message: String) {
    shared.error(message)
  }
}
