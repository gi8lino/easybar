import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config {

    static let shared = Config()

    var barHeight: CGFloat = ConfigDefaults.barHeight
    var barPadding: CGFloat = ConfigDefaults.barPadding

    var barBackgroundHex: String = ConfigDefaults.barBackgroundHex
    var barBorderHex: String = ConfigDefaults.barBorderHex
    var textColorHex: String = ConfigDefaults.textColorHex
    var focusedAppBorderHex: String = ConfigDefaults.focusedAppBorderHex

    var luaPath: String = ConfigDefaults.luaPath

    var logToFile: Bool = ConfigDefaults.logToFile
    var logFilePath: String = ConfigDefaults.logFilePath

    var builtinCPU: CPUBuiltinConfig = ConfigDefaults.builtinCPU
    var builtinBattery: BatteryBuiltinConfig = ConfigDefaults.builtinBattery
    var builtinSpaces: SpacesBuiltinConfig = ConfigDefaults.builtinSpaces
    var builtinFrontApp: FrontAppBuiltinConfig = ConfigDefaults.builtinFrontApp
    var builtinVolume: VolumeBuiltinConfig = ConfigDefaults.builtinVolume
    var builtinDate: DateBuiltinConfig = ConfigDefaults.builtinDate
    var builtinTime: TimeBuiltinConfig = ConfigDefaults.builtinTime
    var builtinCalendar: CalendarBuiltinConfig = ConfigDefaults.builtinCalendar

    /// Absolute path to the widgets directory.
    var widgetsPath: String = ""

    private init() {
        resetDerivedDefaults()

        do {
            try load()
        } catch {
            let message = "invalid config at \(configPath): \(error)"
            Logger.info(message)
            fputs("easybar: \(message)\n", stderr)
            exit(1)
        }
    }

    /// Reloads configuration from disk.
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
            Logger.info("reload rejected: \(error)")
        }
    }

    /// Absolute path to the config file.
    var configPath: String {
        if let override = ProcessInfo.processInfo.environment["EASYBAR_CONFIG_PATH"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return NSString(string: override).expandingTildeInPath
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/easybar/config.toml")
            .path
    }

    // MARK: - Spaces compatibility accessors

    // Keep old runtime call-sites unchanged.
    var spaceSpacing: CGFloat {
        get { CGFloat(builtinSpaces.layout.spacing) }
        set { builtinSpaces.layout.spacing = Double(newValue) }
    }

    var hideEmptySpaces: Bool {
        get { builtinSpaces.layout.hideEmpty }
        set { builtinSpaces.layout.hideEmpty = newValue }
    }

    var spacePaddingX: CGFloat {
        get { CGFloat(builtinSpaces.layout.paddingX) }
        set { builtinSpaces.layout.paddingX = Double(newValue) }
    }

    var spacePaddingY: CGFloat {
        get { CGFloat(builtinSpaces.layout.paddingY) }
        set { builtinSpaces.layout.paddingY = Double(newValue) }
    }

    var spaceCornerRadius: CGFloat {
        get { CGFloat(builtinSpaces.layout.cornerRadius) }
        set { builtinSpaces.layout.cornerRadius = Double(newValue) }
    }

    var spaceFocusedScale: CGFloat {
        get { CGFloat(builtinSpaces.layout.focusedScale) }
        set { builtinSpaces.layout.focusedScale = Double(newValue) }
    }

    var spaceInactiveOpacity: Double {
        get { builtinSpaces.layout.inactiveOpacity }
        set { builtinSpaces.layout.inactiveOpacity = newValue }
    }

    var maxIconsPerSpace: Int {
        get { builtinSpaces.layout.maxIcons }
        set { builtinSpaces.layout.maxIcons = newValue }
    }

    var showSpaceNumber: Bool {
        get { builtinSpaces.layout.showNumber }
        set { builtinSpaces.layout.showNumber = newValue }
    }

    var showSpaceIcons: Bool {
        get { builtinSpaces.layout.showIcons }
        set { builtinSpaces.layout.showIcons = newValue }
    }

    var showOnlyFocusedLabel: Bool {
        get { builtinSpaces.layout.showOnlyFocusedLabel }
        set { builtinSpaces.layout.showOnlyFocusedLabel = newValue }
    }

    var collapseInactiveSpaces: Bool {
        get { builtinSpaces.layout.collapseInactive }
        set { builtinSpaces.layout.collapseInactive = newValue }
    }

    var collapsedSpacePaddingX: CGFloat {
        get { CGFloat(builtinSpaces.layout.collapsedPaddingX) }
        set { builtinSpaces.layout.collapsedPaddingX = Double(newValue) }
    }

    var collapsedSpacePaddingY: CGFloat {
        get { CGFloat(builtinSpaces.layout.collapsedPaddingY) }
        set { builtinSpaces.layout.collapsedPaddingY = Double(newValue) }
    }

    var spaceTextSize: CGFloat {
        get { CGFloat(builtinSpaces.text.size) }
        set { builtinSpaces.text.size = Double(newValue) }
    }

    var spaceTextWeight: String {
        get { builtinSpaces.text.weight }
        set { builtinSpaces.text.weight = newValue }
    }

    var spaceFocusedTextHex: String {
        get { builtinSpaces.text.focusedColorHex }
        set { builtinSpaces.text.focusedColorHex = newValue }
    }

    var spaceInactiveTextHex: String {
        get { builtinSpaces.text.inactiveColorHex }
        set { builtinSpaces.text.inactiveColorHex = newValue }
    }

    var iconSize: CGFloat {
        get { CGFloat(builtinSpaces.icons.size) }
        set { builtinSpaces.icons.size = Double(newValue) }
    }

    var iconSpacing: CGFloat {
        get { CGFloat(builtinSpaces.icons.spacing) }
        set { builtinSpaces.icons.spacing = Double(newValue) }
    }

    var iconCornerRadius: CGFloat {
        get { CGFloat(builtinSpaces.icons.cornerRadius) }
        set { builtinSpaces.icons.cornerRadius = Double(newValue) }
    }

    var focusedIconSize: CGFloat {
        get { CGFloat(builtinSpaces.icons.focusedSize) }
        set { builtinSpaces.icons.focusedSize = Double(newValue) }
    }

    var iconBorderWidth: CGFloat {
        get { CGFloat(builtinSpaces.icons.borderWidth) }
        set { builtinSpaces.icons.borderWidth = Double(newValue) }
    }

    var focusedIconBorderWidth: CGFloat {
        get { CGFloat(builtinSpaces.icons.focusedBorderWidth) }
        set { builtinSpaces.icons.focusedBorderWidth = Double(newValue) }
    }

    var spaceActiveBackgroundHex: String {
        get { builtinSpaces.colors.activeBackgroundHex }
        set { builtinSpaces.colors.activeBackgroundHex = newValue }
    }

    var spaceInactiveBackgroundHex: String {
        get { builtinSpaces.colors.inactiveBackgroundHex }
        set { builtinSpaces.colors.inactiveBackgroundHex = newValue }
    }

    var spaceActiveBorderHex: String {
        get { builtinSpaces.colors.activeBorderHex }
        set { builtinSpaces.colors.activeBorderHex = newValue }
    }

    var spaceInactiveBorderHex: String {
        get { builtinSpaces.colors.inactiveBorderHex }
        set { builtinSpaces.colors.inactiveBorderHex = newValue }
    }

    /// Returns the configured font weight for space labels.
    var resolvedSpaceTextWeight: Font.Weight {
        switch spaceTextWeight.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .semibold
        }
    }

    /// Restores defaults derived from the user's home directory.
    func resetDerivedDefaults() {
        widgetsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/easybar/widgets")
            .path
    }

    /// Restores all static defaults before parsing TOML again.
    func resetAllToDefaults() {
        barHeight = ConfigDefaults.barHeight
        barPadding = ConfigDefaults.barPadding

        barBackgroundHex = ConfigDefaults.barBackgroundHex
        barBorderHex = ConfigDefaults.barBorderHex
        textColorHex = ConfigDefaults.textColorHex
        focusedAppBorderHex = ConfigDefaults.focusedAppBorderHex

        luaPath = ConfigDefaults.luaPath

        logToFile = ConfigDefaults.logToFile
        logFilePath = ConfigDefaults.logFilePath

        builtinCPU = ConfigDefaults.builtinCPU
        builtinBattery = ConfigDefaults.builtinBattery
        builtinSpaces = ConfigDefaults.builtinSpaces
        builtinFrontApp = ConfigDefaults.builtinFrontApp
        builtinVolume = ConfigDefaults.builtinVolume
        builtinDate = ConfigDefaults.builtinDate
        builtinTime = ConfigDefaults.builtinTime
        builtinCalendar = ConfigDefaults.builtinCalendar
    }

    private func snapshot() -> ConfigSnapshot {
        ConfigSnapshot(
            barHeight: barHeight,
            barPadding: barPadding,
            barBackgroundHex: barBackgroundHex,
            barBorderHex: barBorderHex,
            textColorHex: textColorHex,
            focusedAppBorderHex: focusedAppBorderHex,
            luaPath: luaPath,
            logToFile: logToFile,
            logFilePath: logFilePath,
            builtinCPU: builtinCPU,
            builtinBattery: builtinBattery,
            builtinSpaces: builtinSpaces,
            builtinFrontApp: builtinFrontApp,
            builtinVolume: builtinVolume,
            builtinDate: builtinDate,
            builtinTime: builtinTime,
            builtinCalendar: builtinCalendar,
            widgetsPath: widgetsPath
        )
    }

    private func apply(_ snapshot: ConfigSnapshot) {
        barHeight = snapshot.barHeight
        barPadding = snapshot.barPadding

        barBackgroundHex = snapshot.barBackgroundHex
        barBorderHex = snapshot.barBorderHex
        textColorHex = snapshot.textColorHex
        focusedAppBorderHex = snapshot.focusedAppBorderHex

        luaPath = snapshot.luaPath

        logToFile = snapshot.logToFile
        logFilePath = snapshot.logFilePath

        builtinCPU = snapshot.builtinCPU
        builtinBattery = snapshot.builtinBattery
        builtinSpaces = snapshot.builtinSpaces
        builtinFrontApp = snapshot.builtinFrontApp
        builtinVolume = snapshot.builtinVolume
        builtinDate = snapshot.builtinDate
        builtinTime = snapshot.builtinTime
        builtinCalendar = snapshot.builtinCalendar

        widgetsPath = snapshot.widgetsPath

        Logger.configure(logToFile: logToFile, filePath: logFilePath)
    }
}
