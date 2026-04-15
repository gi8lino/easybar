import EasyBarShared
import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config: ObservableObject {
  static let shared = Config()

  enum LoadFailureContext {
    case initialLoad
    case reloadKeptPreviousConfig
  }

  struct LoadFailureState {
    let error: any Error
    let context: LoadFailureContext
  }

  // MARK: - Sections

  struct AppSection {
    var widgetsPath: String
    var luaPath: String
    var watchConfigFile: Bool
    var lockDirectory: String
  }

  struct LoggingSection {
    var enabled: Bool
    var level: ProcessLogLevel
    var directory: String
  }

  struct CalendarAgentSection {
    var enabled: Bool
    var socketPath: String
  }

  struct NetworkAgentSection {
    var enabled: Bool
    var socketPath: String
    var refreshIntervalSeconds: Double
    var allowUnauthorizedNonSensitiveFields: Bool
  }

  // MARK: - Stored config sections

  var appSection: AppSection
  var loggingSection: LoggingSection
  var calendarAgentSection: CalendarAgentSection
  var networkAgentSection: NetworkAgentSection

  // MARK: - App compatibility accessors

  var widgetsPath: String {
    get { appSection.widgetsPath }
    set { appSection.widgetsPath = newValue }
  }

  var luaPath: String {
    get { appSection.luaPath }
    set { appSection.luaPath = newValue }
  }

  var watchConfigFile: Bool {
    get { appSection.watchConfigFile }
    set { appSection.watchConfigFile = newValue }
  }

  var lockDirectory: String {
    get { appSection.lockDirectory }
    set { appSection.lockDirectory = newValue }
  }

  var loggingEnabled: Bool {
    get { loggingSection.enabled }
    set { loggingSection.enabled = newValue }
  }

  var loggingLevel: ProcessLogLevel {
    get { loggingSection.level }
    set { loggingSection.level = newValue }
  }

  var loggingDebugEnabled: Bool {
    get { loggingSection.level.allows(.debug) }
    set { loggingSection.level = newValue ? .debug : .info }
  }

  var loggingTraceEnabled: Bool {
    get { loggingSection.level.allows(.trace) }
    set { loggingSection.level = newValue ? .trace : .info }
  }

  var loggingDirectory: String {
    get { loggingSection.directory }
    set { loggingSection.directory = newValue }
  }

  var calendarAgentEnabled: Bool {
    get { calendarAgentSection.enabled }
    set { calendarAgentSection.enabled = newValue }
  }

  var calendarAgentSocketPath: String {
    get { calendarAgentSection.socketPath }
    set { calendarAgentSection.socketPath = newValue }
  }

  var networkAgentEnabled: Bool {
    get { networkAgentSection.enabled }
    set { networkAgentSection.enabled = newValue }
  }

  var networkAgentSocketPath: String {
    get { networkAgentSection.socketPath }
    set { networkAgentSection.socketPath = newValue }
  }

  var networkAgentRefreshIntervalSeconds: Double {
    get { networkAgentSection.refreshIntervalSeconds }
    set { networkAgentSection.refreshIntervalSeconds = newValue }
  }

  var networkAgentAllowUnauthorizedNonSensitiveFields: Bool {
    get { networkAgentSection.allowUnauthorizedNonSensitiveFields }
    set { networkAgentSection.allowUnauthorizedNonSensitiveFields = newValue }
  }

  // MARK: - Bar

  var barHeight: CGFloat = 32
  var barPaddingX: CGFloat = 10
  var barExtendBehindNotch: Bool = true

  var barBackgroundHex: String = "#111111"
  var barBorderHex: String = "#222222"

  // MARK: - Builtins

  var builtinCPU: CPUBuiltinConfig = .default
  var builtinBattery: BatteryBuiltinConfig = .default
  var builtinGroups: [BuiltinGroupConfig] = []
  var builtinSpaces: SpacesBuiltinConfig = .default
  var builtinFrontApp: FrontAppBuiltinConfig = .default
  var builtinAeroSpaceMode: AeroSpaceModeBuiltinConfig = .default
  var builtinVolume: VolumeBuiltinConfig = .default
  var builtinWiFi: WiFiBuiltinConfig = .default
  var builtinCalendar: CalendarBuiltinConfig = .default
  var builtinTime: TimeBuiltinConfig = .default
  var builtinDate: DateBuiltinConfig = .default

  private(set) var loadFailureState: LoadFailureState?

  private init() {
    appSection = .init(
      widgetsPath: "",
      luaPath: "/opt/homebrew/bin/lua",
      watchConfigFile: false,
      lockDirectory: ""
    )
    loggingSection = .init(
      enabled: false,
      level: .info,
      directory: ""
    )
    calendarAgentSection = .init(
      enabled: true,
      socketPath: ""
    )
    networkAgentSection = .init(
      enabled: true,
      socketPath: "",
      refreshIntervalSeconds: 15,
      allowUnauthorizedNonSensitiveFields: false
    )

    resetDerivedDefaults()

    do {
      let loadStart = Date()
      try load()
      logSlowPhase(name: "initial load", startedAt: loadStart)

      loadFailureState = nil
    } catch {
      let message = "invalid config at \(configPath): \(error)"
      easybarLog.error(message)
      fputs("easybar: \(message)\n", stderr)
      loadFailureState = LoadFailureState(error: error, context: .initialLoad)
    }
  }

  /// Reloads config from disk and returns one validation error when reload fails.
  @discardableResult
  func reload() -> (any Error)? {
    easybarLog.info("reloading configuration path=\(configPath)")

    let snapshotStart = Date()
    let snapshot = snapshot()
    logSlowPhase(name: "snapshot", startedAt: snapshotStart)

    let resetStart = Date()
    resetToDefaults()
    logSlowPhase(name: "resetToDefaults", startedAt: resetStart)

    do {
      let loadStart = Date()
      try load()
      logSlowPhase(name: "load", startedAt: loadStart)

      let publishStart = Date()
      loadFailureState = nil
      objectWillChange.send()
      logSlowPhase(name: "objectWillChange.send", startedAt: publishStart)

      easybarLog.info("reload applied")
      return nil
    } catch {
      let rollbackStart = Date()
      apply(snapshot)
      loadFailureState = LoadFailureState(error: error, context: .reloadKeptPreviousConfig)
      logSlowPhase(name: "rollback apply(snapshot)", startedAt: rollbackStart)

      easybarLog.warn("reload rejected: \(error)")
      return error
    }
  }

  /// Absolute path to the active config file.
  var configPath: String {
    if let override = environmentConfigPathOverride() {
      return override
    }

    return FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/config.toml")
      .path
  }

  /// Restores all defaults before parsing again.
  func resetToDefaults() {
    resetStaticDefaults()
    resetDerivedDefaults()
  }

  /// Restores bar defaults.
  func resetBarDefaults() {
    barHeight = 32
    barPaddingX = 10
    barExtendBehindNotch = true

    barBackgroundHex = "#111111"
    barBorderHex = "#222222"
  }

  /// Restores built-in widget defaults.
  func resetBuiltinDefaults() {
    builtinCPU = .default
    builtinBattery = .default
    builtinGroups = []
    builtinSpaces = .default
    builtinFrontApp = .default
    builtinAeroSpaceMode = .default
    builtinVolume = .default
    builtinWiFi = .default
    builtinCalendar = .default
    builtinTime = .default
    builtinDate = .default
  }

  /// Logs one config phase duration when it looks unexpectedly slow.
  private func logSlowPhase(
    name: String,
    startedAt: Date,
    slowThreshold: TimeInterval = 0.1
  ) {
    let elapsed = Date().timeIntervalSince(startedAt)
    guard elapsed >= slowThreshold else { return }

    let milliseconds = Int((elapsed * 1000).rounded())
    easybarLog.warn("slow config phase phase=\(name) duration_ms=\(milliseconds)")
  }
}
