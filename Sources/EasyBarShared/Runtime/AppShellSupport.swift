import Foundation

/// Result of starting a standalone EasyBar helper agent.
public enum AgentAppStartResult {
  case running
  case disabled
  case failed

  /// Process exit code when startup should terminate, or nil while the agent is running.
  public var terminationExitCode: Int32? {
    switch self {
    case .running: return nil
    case .disabled: return 0
    case .failed: return 1
    }
  }
}

/// Shared helpers for macOS app-shell startup, locking, and logging.
public enum AppShellSupport {
  /// Loads shared configuration and prepares logging and single-instance ownership.
  public static func prepareAgent(
    processName: String,
    logFileName: String,
    logger: ProcessLogger,
    instanceGuard: SingleInstanceGuard
  ) -> SharedRuntimeConfig? {
    let config: SharedRuntimeConfig

    do {
      config = try SharedRuntimeConfig.load()
    } catch {
      logger.error(
        "failed to load shared runtime config",
        .field("error", error.localizedDescription)
      )
      return nil
    }

    configureLogging(
      logger: logger,
      minimumLevel: config.logging.level,
      fileLoggingEnabled: config.logging.enabled,
      loggingDirectory: config.logging.directory,
      logFileName: logFileName
    )

    guard
      acquireInstanceLock(
        instanceGuard: instanceGuard,
        processName: processName,
        directory: config.app.lockDirectory,
        logger: logger,
        acquireMessage: "\(processName) acquired instance lock",
        alreadyRunningMessage: "\(processName) already running",
        failureMessage: "\(processName) failed to acquire single-instance lock"
      )
    else {
      return nil
    }

    return config
  }

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
    acquireMessage: String,
    alreadyRunningMessage: String,
    failureMessage: String
  ) -> Bool {
    switch instanceGuard.acquireLock(processName: processName, directory: directory) {
    case .acquired(let lockPath):
      logger.info(acquireMessage, .field("lock_path", lockPath))
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
