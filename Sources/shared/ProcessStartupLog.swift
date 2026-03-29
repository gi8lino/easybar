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
