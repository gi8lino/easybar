import Foundation

/// Shared helpers for macOS app-shell startup, locking, and logging.
public enum AppShellSupport {
  /// Configures runtime logging for one app shell.
  public static func configureLogging(
    logger: ProcessLogger,
    minimumLevel: ProcessLogLevel,
    fileLoggingEnabled: Bool,
    loggingDirectory: String,
    logFileName: String
  ) {
    logger.configureRuntimeLogging(
      minimumLevel: minimumLevel,
      fileLoggingEnabled: fileLoggingEnabled,
      fileLoggingPath: URL(fileURLWithPath: loggingDirectory)
        .appendingPathComponent(logFileName)
        .path
    )
  }

  /// Acquires the single-instance lock for one process and logs failures consistently.
  @discardableResult
  public static func acquireInstanceLock(
    instanceGuard: SingleInstanceGuard,
    processName: String,
    directory: String,
    logger: ProcessLogger,
    alreadyRunningMessage: String,
    failureMessage: String
  ) -> Bool {
    switch instanceGuard.acquireLock(processName: processName, directory: directory) {
    case .acquired:
      return true
    case .alreadyRunning(let lockPath):
      logger.warn(alreadyRunningMessage, .field("lock_path", lockPath))
      return false
    case .failed(let lockPath, let reason):
      logger.error(
        failureMessage,
        .field("lock_path", lockPath),
        .field("reason", reason)
      )
      return false
    }
  }
}
