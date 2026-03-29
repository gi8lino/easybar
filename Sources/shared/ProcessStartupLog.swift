import Foundation

/// Startup details logged by one EasyBar process.
public struct ProcessStartupSnapshot {
  public let processName: String
  public let bundlePath: String
  public let executablePath: String
  public let version: String
  public let build: String
  public let bundleIdentifier: String
  public let processIdentifier: Int32
  public let configPath: String
  public let socketSummary: String
  public let loggingSummary: String

  /// Creates one startup log snapshot.
  public init(
    processName: String,
    bundlePath: String,
    executablePath: String,
    version: String,
    build: String,
    bundleIdentifier: String,
    processIdentifier: Int32,
    configPath: String,
    socketSummary: String,
    loggingSummary: String
  ) {
    self.processName = processName
    self.bundlePath = bundlePath
    self.executablePath = executablePath
    self.version = version
    self.build = build
    self.bundleIdentifier = bundleIdentifier
    self.processIdentifier = processIdentifier
    self.configPath = configPath
    self.socketSummary = socketSummary
    self.loggingSummary = loggingSummary
  }
}

/// Builds one startup snapshot from the main bundle plus process-specific details.
public func makeProcessStartupSnapshot(
  processName: String,
  configPath: String,
  socketSummary: String,
  loggingSummary: String,
  bundle: Bundle = .main,
  processInfo: ProcessInfo = .processInfo
) -> ProcessStartupSnapshot {
  let info = bundle.infoDictionary ?? [:]

  return ProcessStartupSnapshot(
    processName: processName,
    bundlePath: bundle.bundleURL.path,
    executablePath: bundle.executableURL?.path ?? "unknown",
    version: info["CFBundleShortVersionString"] as? String ?? "unknown",
    build: info["CFBundleVersion"] as? String ?? "unknown",
    bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
    processIdentifier: processInfo.processIdentifier,
    configPath: configPath,
    socketSummary: socketSummary,
    loggingSummary: loggingSummary
  )
}

/// Writes one standard startup log block.
public func logProcessStartup(
  snapshot: ProcessStartupSnapshot,
  write: (String) -> Void
) {
  write(
    "\(snapshot.processName) startup version=\(snapshot.version) build=\(snapshot.build) bundle_id=\(snapshot.bundleIdentifier) pid=\(snapshot.processIdentifier)"
  )
  write("app bundle_path=\(snapshot.bundlePath)")
  write("app executable=\(snapshot.executablePath)")
  write("config path=\(snapshot.configPath)")
  write(snapshot.socketSummary)
  write(snapshot.loggingSummary)
}
