import Foundation

/// Writes one standard startup log block.
public func logProcessStartup(
  processName: String,
  configPath: String,
  socketPath: String,
  logger: ProcessLogger,
  bundle: Bundle = .main,
  processInfo: ProcessInfo = .processInfo
) {
  let info = bundle.infoDictionary ?? [:]
  let version = info["CFBundleShortVersionString"] as? String ?? "unknown"
  let build = info["CFBundleVersion"] as? String ?? "unknown"

  logger.info(
    "process startup",
    .field("process", processName),
    .field("event", "startup"),
    .field("version", version),
    .field("build", build),
    .field("bundle_id", bundle.bundleIdentifier ?? "unknown"),
    .field("pid", processInfo.processIdentifier),
    .field("run_id", logger.runID)
  )

  logger.info(
    "process startup bundle",
    .field("app_bundle_path", bundle.bundleURL.path)
  )

  logger.info(
    "process startup executable",
    .field("app_executable", bundle.executableURL?.path ?? "unknown")
  )

  logger.info(
    "process startup config",
    .field("config_path", configPath)
  )

  logger.info(
    "process startup socket",
    .field("socket_path", socketPath)
  )

  logger.info(
    "process startup logging",
    .field("logging_enabled", logger.fileLoggingEnabled),
    .field("level", logger.minimumLevel.rawValue),
    .field("path", logger.fileLoggingPath)
  )
}
