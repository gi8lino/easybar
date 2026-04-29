import Foundation

/// Writes one standard startup log block.
public func logProcessStartup(
  processName: String,
  configPath: String,
  socketSummary: String,
  loggingSummary: String,
  write: (String) -> Void,
  bundle: Bundle = .main,
  processInfo: ProcessInfo = .processInfo
) {
  let info = bundle.infoDictionary ?? [:]
  write(
    formatLogFields(
      "process", processName,
      "event", "startup",
      "version", "\(info["CFBundleShortVersionString"] as? String ?? "unknown")",
      "build", "\(info["CFBundleVersion"] as? String ?? "unknown")",
      "bundle_id", "\(bundle.bundleIdentifier ?? "unknown")",
      "pid", processInfo.processIdentifier
    ))
  write(formatLogFields("app_bundle_path", bundle.bundleURL.path))
  write(formatLogFields("app_executable", bundle.executableURL?.path ?? "unknown"))
  write(formatLogFields("config_path", configPath))
  write(socketSummary)
  write(loggingSummary)
}
