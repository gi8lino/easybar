import EasyBarShared
import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config {

  static let shared = Config()

  // MARK: - Sections

  struct AppSection {
    var widgetsPath: String
    var luaPath: String
    var watchConfigFile: Bool
    var lockDirectory: String
  }

  struct LoggingSection {
    var enabled: Bool
    var debugEnabled: Bool
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

  private var appSection: AppSection
  private var loggingSection: LoggingSection
  private var calendarAgentSection: CalendarAgentSection
  private var networkAgentSection: NetworkAgentSection

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

  var loggingDebugEnabled: Bool {
    get { loggingSection.debugEnabled }
    set { loggingSection.debugEnabled = newValue }
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
  var builtinVolume: VolumeBuiltinConfig = .default
  var builtinWiFi: WiFiBuiltinConfig = .default
  var builtinCalendar: CalendarBuiltinConfig = .default
  var builtinTime: TimeBuiltinConfig = .default
  var builtinDate: DateBuiltinConfig = .default

  private init() {
    appSection = .init(
      widgetsPath: "",
      luaPath: "/opt/homebrew/bin/lua",
      watchConfigFile: false,
      lockDirectory: ""
    )
    loggingSection = .init(
      enabled: false,
      debugEnabled: false,
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
      try load()
    } catch {
      let message = "invalid config at \(configPath): \(error)"
      easybarLog.error(message)
      fputs("easybar: \(message)\n", stderr)
      exit(1)
    }
  }

  /// Reloads config from disk.
  func reload() {
    easybarLog.info("reloading configuration")

    let snapshot = snapshot()

    resetToDefaults()

    do {
      try load()
      easybarLog.info("reload applied")
    } catch {
      apply(snapshot)
      easybarLog.warn("reload rejected: \(error)")
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

  /// Restores defaults derived from the current home directory.
  private func resetDerivedDefaults() {
    appSection.widgetsPath =
      FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/widgets")
      .path
    appSection.lockDirectory = defaultSingleInstanceLockDirectory()

    loggingSection.directory = defaultLoggingDirectoryPath()

    calendarAgentSection.socketPath = defaultCalendarAgentSocketPath()

    networkAgentSection.socketPath = defaultNetworkAgentSocketPath()
    networkAgentSection.refreshIntervalSeconds = 60
    networkAgentSection.allowUnauthorizedNonSensitiveFields = false
  }

  /// Restores all static defaults before parsing again.
  private func resetStaticDefaults() {
    resetAppDefaults()
    resetLoggingDefaults()
    resetAgentDefaults()
    resetBarDefaults()
    resetBuiltinDefaults()
  }

  /// Restores app-level defaults.
  private func resetAppDefaults() {
    appSection.luaPath = "/opt/homebrew/bin/lua"
    appSection.watchConfigFile = false
  }

  /// Restores logging defaults.
  private func resetLoggingDefaults() {
    loggingSection.enabled = false
    loggingSection.debugEnabled = false
  }

  /// Restores agent defaults.
  private func resetAgentDefaults() {
    calendarAgentSection.enabled = true

    networkAgentSection.enabled = true
    networkAgentSection.refreshIntervalSeconds = 60
    networkAgentSection.allowUnauthorizedNonSensitiveFields = false
  }

  /// Restores bar defaults.
  private func resetBarDefaults() {
    barHeight = 32
    barPaddingX = 10
    barExtendBehindNotch = true

    barBackgroundHex = "#111111"
    barBorderHex = "#222222"
  }

  /// Restores built-in widget defaults.
  private func resetBuiltinDefaults() {
    builtinCPU = .default
    builtinBattery = .default
    builtinGroups = []
    builtinSpaces = .default
    builtinFrontApp = .default
    builtinVolume = .default
    builtinWiFi = .default
    builtinCalendar = .default
    builtinTime = .default
    builtinDate = .default
  }

  /// Captures the current config state.
  private func snapshot() -> ConfigSnapshot {
    ConfigSnapshot(
      app: .init(
        widgetsPath: appSection.widgetsPath,
        luaPath: appSection.luaPath,
        watchConfigFile: appSection.watchConfigFile,
        lockDirectory: appSection.lockDirectory
      ),
      logging: .init(
        enabled: loggingSection.enabled,
        debugEnabled: loggingSection.debugEnabled,
        directory: loggingSection.directory
      ),
      calendarAgent: .init(
        enabled: calendarAgentSection.enabled,
        socketPath: calendarAgentSection.socketPath
      ),
      networkAgent: .init(
        enabled: networkAgentSection.enabled,
        socketPath: networkAgentSection.socketPath,
        refreshIntervalSeconds: networkAgentSection.refreshIntervalSeconds,
        allowUnauthorizedNonSensitiveFields:
          networkAgentSection.allowUnauthorizedNonSensitiveFields
      ),
      bar: .init(
        height: barHeight,
        paddingX: barPaddingX,
        extendBehindNotch: barExtendBehindNotch,
        backgroundHex: barBackgroundHex,
        borderHex: barBorderHex
      ),
      builtins: .init(
        cpu: builtinCPU,
        battery: builtinBattery,
        groups: builtinGroups,
        spaces: builtinSpaces,
        frontApp: builtinFrontApp,
        volume: builtinVolume,
        wifi: builtinWiFi,
        calendar: builtinCalendar,
        time: builtinTime,
        date: builtinDate
      )
    )
  }

  /// Restores one previous config snapshot.
  private func apply(_ snapshot: ConfigSnapshot) {
    applyAppSnapshot(snapshot)
    applyBarSnapshot(snapshot)
    applyBuiltinSnapshot(snapshot)
  }

  /// Restores the app-level config snapshot.
  private func applyAppSnapshot(_ snapshot: ConfigSnapshot) {
    appSection = .init(
      widgetsPath: snapshot.app.widgetsPath,
      luaPath: snapshot.app.luaPath,
      watchConfigFile: snapshot.app.watchConfigFile,
      lockDirectory: snapshot.app.lockDirectory
    )

    loggingSection = .init(
      enabled: snapshot.logging.enabled,
      debugEnabled: snapshot.logging.debugEnabled,
      directory: snapshot.logging.directory
    )

    calendarAgentSection = .init(
      enabled: snapshot.calendarAgent.enabled,
      socketPath: snapshot.calendarAgent.socketPath
    )

    networkAgentSection = .init(
      enabled: snapshot.networkAgent.enabled,
      socketPath: snapshot.networkAgent.socketPath,
      refreshIntervalSeconds: snapshot.networkAgent.refreshIntervalSeconds,
      allowUnauthorizedNonSensitiveFields:
        snapshot.networkAgent.allowUnauthorizedNonSensitiveFields
    )
  }

  /// Restores the bar config snapshot.
  private func applyBarSnapshot(_ snapshot: ConfigSnapshot) {
    barHeight = snapshot.bar.height
    barPaddingX = snapshot.bar.paddingX
    barExtendBehindNotch = snapshot.bar.extendBehindNotch

    barBackgroundHex = snapshot.bar.backgroundHex
    barBorderHex = snapshot.bar.borderHex
  }

  /// Restores the built-in widget config snapshot.
  private func applyBuiltinSnapshot(_ snapshot: ConfigSnapshot) {
    builtinCPU = snapshot.builtins.cpu
    builtinBattery = snapshot.builtins.battery
    builtinGroups = snapshot.builtins.groups
    builtinSpaces = snapshot.builtins.spaces
    builtinFrontApp = snapshot.builtins.frontApp
    builtinVolume = snapshot.builtins.volume
    builtinWiFi = snapshot.builtins.wifi
    builtinCalendar = snapshot.builtins.calendar
    builtinTime = snapshot.builtins.time
    builtinDate = snapshot.builtins.date
  }
}

/// Returns the default directory used for single-instance lock files.
private func defaultSingleInstanceLockDirectory() -> String {
  "/tmp/EasyBar"
}

/// Returns the default Unix socket path used by the calendar agent.
private func defaultCalendarAgentSocketPath() -> String {
  "/tmp/EasyBar/calendar-agent.sock"
}

/// Returns the default Unix socket path used by the network agent.
private func defaultNetworkAgentSocketPath() -> String {
  "/tmp/EasyBar/network-agent.sock"
}
