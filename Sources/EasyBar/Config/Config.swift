import EasyBarShared
import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config {

  static let shared = Config()

  // MARK: - App

  var widgetsPath: String = ""
  var luaPath: String = "/opt/homebrew/bin/lua"
  var watchConfigFile: Bool = false
  var loggingEnabled: Bool = false
  var loggingDebugEnabled: Bool = false
  var loggingDirectory: String = ""
  var calendarAgentEnabled: Bool = true
  var calendarAgentSocketPath: String = ""
  var networkAgentEnabled: Bool = true
  var networkAgentSocketPath: String = ""
  var networkAgentRefreshIntervalSeconds: Double = 15
  var networkAgentAllowUnauthorizedNonSensitiveFields: Bool = false

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
    resetDerivedDefaults()

    do {
      try load()
    } catch {
      let message = "invalid config at \(configPath): \(error)"
      Logger.error(message)
      fputs("easybar: \(message)\n", stderr)
      exit(1)
    }
  }

  /// Reloads config from disk.
  func reload() {
    Logger.info("reloading configuration")

    let snapshot = snapshot()

    resetToDefaults()

    do {
      try load()
      Logger.info("reload applied")
    } catch {
      apply(snapshot)
      Logger.warn("reload rejected: \(error)")
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
    widgetsPath =
      FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/easybar/widgets")
      .path
    loggingDirectory =
      defaultLoggingDirectoryPath()
    calendarAgentSocketPath = defaultCalendarAgentSocketPath()
    networkAgentSocketPath = defaultNetworkAgentSocketPath()
    networkAgentRefreshIntervalSeconds = 60
    networkAgentAllowUnauthorizedNonSensitiveFields = false
  }

  /// Restores all static defaults before parsing again.
  private func resetStaticDefaults() {
    resetAppDefaults()
    resetBarDefaults()
    resetBuiltinDefaults()
  }

  /// Restores app-level defaults.
  private func resetAppDefaults() {
    luaPath = "/opt/homebrew/bin/lua"
    watchConfigFile = false
    loggingEnabled = false
    loggingDebugEnabled = false
    calendarAgentEnabled = true
    networkAgentEnabled = true
    networkAgentRefreshIntervalSeconds = 60
    networkAgentAllowUnauthorizedNonSensitiveFields = false
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
        widgetsPath: widgetsPath,
        luaPath: luaPath,
        watchConfigFile: watchConfigFile,
        loggingEnabled: loggingEnabled,
        loggingDebugEnabled: loggingDebugEnabled,
        loggingDirectory: loggingDirectory,
        calendarAgentEnabled: calendarAgentEnabled,
        calendarAgentSocketPath: calendarAgentSocketPath,
        networkAgentEnabled: networkAgentEnabled,
        networkAgentSocketPath: networkAgentSocketPath,
        networkAgentRefreshIntervalSeconds: networkAgentRefreshIntervalSeconds,
        networkAgentAllowUnauthorizedNonSensitiveFields:
          networkAgentAllowUnauthorizedNonSensitiveFields
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
    widgetsPath = snapshot.app.widgetsPath
    luaPath = snapshot.app.luaPath
    watchConfigFile = snapshot.app.watchConfigFile
    loggingEnabled = snapshot.app.loggingEnabled
    loggingDebugEnabled = snapshot.app.loggingDebugEnabled
    loggingDirectory = snapshot.app.loggingDirectory
    calendarAgentEnabled = snapshot.app.calendarAgentEnabled
    calendarAgentSocketPath = snapshot.app.calendarAgentSocketPath
    networkAgentEnabled = snapshot.app.networkAgentEnabled
    networkAgentSocketPath = snapshot.app.networkAgentSocketPath
    networkAgentRefreshIntervalSeconds = snapshot.app.networkAgentRefreshIntervalSeconds
    networkAgentAllowUnauthorizedNonSensitiveFields =
      snapshot.app.networkAgentAllowUnauthorizedNonSensitiveFields
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
