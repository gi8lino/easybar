import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config {

    static let shared = Config()

    // MARK: - App

    var widgetsPath: String = ""
    var luaPath: String = "/usr/local/bin/lua"
    var watchConfigFile: Bool = true
    var loggingEnabled: Bool = false
    var loggingPath: String = ""

    // MARK: - Bar

    var barHeight: CGFloat = 32
    var barPaddingX: CGFloat = 10
    var barExtendBehindNotch: Bool = false

    var barBackgroundHex: String = "#111111"
    var barBorderHex: String = "#222222"

    // MARK: - Builtins

    var builtinCPU: CPUBuiltinConfig = .default
    var builtinBattery: BatteryBuiltinConfig = .default
    var builtinSpaces: SpacesBuiltinConfig = .default
    var builtinFrontApp: FrontAppBuiltinConfig = .default
    var builtinVolume: VolumeBuiltinConfig = .default
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

        resetAllToDefaults()
        resetDerivedDefaults()

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

    /// Restores defaults derived from the current home directory.
    func resetDerivedDefaults() {
        widgetsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/easybar/widgets")
            .path
        loggingPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/state/easybar/easybar.out")
            .path
    }

    /// Restores all static defaults before parsing again.
    func resetAllToDefaults() {
        luaPath = "/usr/local/bin/lua"
        watchConfigFile = true
        loggingEnabled = false

        barHeight = 32
        barPaddingX = 10
        barExtendBehindNotch = false

        barBackgroundHex = "#111111"
        barBorderHex = "#222222"

        builtinCPU = .default
        builtinBattery = .default
        builtinSpaces = .default
        builtinFrontApp = .default
        builtinVolume = .default
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
            loggingPath: loggingPath,
            barHeight: barHeight,
            barPaddingX: barPaddingX,
            barExtendBehindNotch: barExtendBehindNotch,
            barBackgroundHex: barBackgroundHex,
            barBorderHex: barBorderHex,
            builtinCPU: builtinCPU,
            builtinBattery: builtinBattery,
            builtinSpaces: builtinSpaces,
            builtinFrontApp: builtinFrontApp,
            builtinVolume: builtinVolume,
            builtinCalendar: builtinCalendar,
            builtinTime: builtinTime,
            builtinDate: builtinDate
        )
    }

    /// Restores one previous config snapshot.
    private func apply(_ snapshot: ConfigSnapshot) {
        widgetsPath = snapshot.widgetsPath
        luaPath = snapshot.luaPath
        watchConfigFile = snapshot.watchConfigFile
        loggingEnabled = snapshot.loggingEnabled
        loggingPath = snapshot.loggingPath

        barHeight = snapshot.barHeight
        barPaddingX = snapshot.barPaddingX
        barExtendBehindNotch = snapshot.barExtendBehindNotch

        barBackgroundHex = snapshot.barBackgroundHex
        barBorderHex = snapshot.barBorderHex

        builtinCPU = snapshot.builtinCPU
        builtinBattery = snapshot.builtinBattery
        builtinSpaces = snapshot.builtinSpaces
        builtinFrontApp = snapshot.builtinFrontApp
        builtinVolume = snapshot.builtinVolume
        builtinCalendar = snapshot.builtinCalendar
        builtinTime = snapshot.builtinTime
        builtinDate = snapshot.builtinDate
    }
}
