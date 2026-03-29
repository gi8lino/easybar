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
      barHeight: barHeight,
      barPaddingX: barPaddingX,
      barExtendBehindNotch: barExtendBehindNotch,
      barBackgroundHex: barBackgroundHex,
      barBorderHex: barBorderHex,
      builtinCPU: builtinCPU,
      builtinBattery: builtinBattery,
      builtinGroups: builtinGroups,
      builtinSpaces: builtinSpaces,
      builtinFrontApp: builtinFrontApp,
      builtinVolume: builtinVolume,
      builtinWiFi: builtinWiFi,
      builtinCalendar: builtinCalendar,
      builtinTime: builtinTime,
      builtinDate: builtinDate
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
    widgetsPath = snapshot.widgetsPath
    luaPath = snapshot.luaPath
    watchConfigFile = snapshot.watchConfigFile
    loggingEnabled = snapshot.loggingEnabled
    loggingDebugEnabled = snapshot.loggingDebugEnabled
    loggingDirectory = snapshot.loggingDirectory
    calendarAgentEnabled = snapshot.calendarAgentEnabled
    calendarAgentSocketPath = snapshot.calendarAgentSocketPath
    networkAgentEnabled = snapshot.networkAgentEnabled
    networkAgentSocketPath = snapshot.networkAgentSocketPath
    networkAgentRefreshIntervalSeconds = snapshot.networkAgentRefreshIntervalSeconds
  }

  /// Restores the bar config snapshot.
  private func applyBarSnapshot(_ snapshot: ConfigSnapshot) {
    barHeight = snapshot.barHeight
    barPaddingX = snapshot.barPaddingX
    barExtendBehindNotch = snapshot.barExtendBehindNotch

    barBackgroundHex = snapshot.barBackgroundHex
    barBorderHex = snapshot.barBorderHex
  }

  /// Restores the built-in widget config snapshot.
  private func applyBuiltinSnapshot(_ snapshot: ConfigSnapshot) {
    builtinCPU = snapshot.builtinCPU
    builtinBattery = snapshot.builtinBattery
    builtinGroups = snapshot.builtinGroups
    builtinSpaces = snapshot.builtinSpaces
    builtinFrontApp = snapshot.builtinFrontApp
    builtinVolume = snapshot.builtinVolume
    builtinWiFi = snapshot.builtinWiFi
    builtinCalendar = snapshot.builtinCalendar
    builtinTime = snapshot.builtinTime
    builtinDate = snapshot.builtinDate
  }
}
