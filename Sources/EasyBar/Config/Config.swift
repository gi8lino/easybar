import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config {

    static let shared = Config()

    // MARK: - App

    var widgetsPath: String = ""
    var luaPath: String = ConfigDefaults.luaPath
    var watchConfigFile: Bool = ConfigDefaults.watchConfigFile

    // MARK: - App logging

    var logToFile: Bool = ConfigDefaults.logToFile
    var logFilePath: String = ConfigDefaults.logFilePath

    // MARK: - Bar

    var barHeight: CGFloat = ConfigDefaults.barHeight
    var barPaddingX: CGFloat = ConfigDefaults.barPaddingX

    var barBackgroundHex: String = ConfigDefaults.barBackgroundHex
    var barBorderHex: String = ConfigDefaults.barBorderHex
    var textColorHex: String = ConfigDefaults.textColorHex
    var focusedAppBorderHex: String = ConfigDefaults.focusedAppBorderHex

    // MARK: - Builtins

    var builtinCPU: CPUBuiltinConfig = ConfigDefaults.builtinCPU
    var builtinBattery: BatteryBuiltinConfig = ConfigDefaults.builtinBattery
    var builtinSpaces: SpacesBuiltinConfig = ConfigDefaults.builtinSpaces
    var builtinFrontApp: FrontAppBuiltinConfig = ConfigDefaults.builtinFrontApp
    var builtinVolume: VolumeBuiltinConfig = ConfigDefaults.builtinVolume
    var builtinCalendar: CalendarBuiltinConfig = ConfigDefaults.builtinCalendar
    var builtinTime: TimeBuiltinConfig = ConfigDefaults.builtinTime
    var builtinDate: DateBuiltinConfig = ConfigDefaults.builtinDate

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
            Logger.warn("reload rejected: \(error)")
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

    /// Space-to-space gap.
    var spaceSpacing: CGFloat {
        get { CGFloat(builtinSpaces.layout.spacing) }
        set { builtinSpaces.layout.spacing = Double(newValue) }
    }

    /// Hides spaces without apps.
    var hideEmptySpaces: Bool {
        get { builtinSpaces.layout.hideEmpty }
        set { builtinSpaces.layout.hideEmpty = newValue }
    }

    /// Horizontal padding inside one space pill.
    var spacePaddingX: CGFloat {
        get { CGFloat(builtinSpaces.layout.paddingX) }
        set { builtinSpaces.layout.paddingX = Double(newValue) }
    }

    /// Vertical padding inside one space pill.
    var spacePaddingY: CGFloat {
        get { CGFloat(builtinSpaces.layout.paddingY) }
        set { builtinSpaces.layout.paddingY = Double(newValue) }
    }

    /// Horizontal margin around the whole spaces widget.
    var spaceMarginX: CGFloat {
        get { CGFloat(builtinSpaces.layout.marginX) }
        set { builtinSpaces.layout.marginX = Double(newValue) }
    }

    /// Vertical margin around the whole spaces widget.
    var spaceMarginY: CGFloat {
        get { CGFloat(builtinSpaces.layout.marginY) }
        set { builtinSpaces.layout.marginY = Double(newValue) }
    }

    /// Corner radius for inactive spaces.
    var spaceCornerRadius: CGFloat {
        get { CGFloat(builtinSpaces.layout.cornerRadius) }
        set { builtinSpaces.layout.cornerRadius = Double(newValue) }
    }

    /// Corner radius for the active space.
    var spaceFocusedCornerRadius: CGFloat {
        get { CGFloat(builtinSpaces.layout.focusedCornerRadius) }
        set { builtinSpaces.layout.focusedCornerRadius = Double(newValue) }
    }

    /// Scale for the active space.
    var spaceFocusedScale: CGFloat {
        get { CGFloat(builtinSpaces.layout.focusedScale) }
        set { builtinSpaces.layout.focusedScale = Double(newValue) }
    }

    /// Opacity for inactive spaces.
    var spaceInactiveOpacity: Double {
        get { builtinSpaces.layout.inactiveOpacity }
        set { builtinSpaces.layout.inactiveOpacity = newValue }
    }

    /// Maximum visible app icons per space.
    var maxIconsPerSpace: Int {
        get { builtinSpaces.layout.maxIcons }
        set { builtinSpaces.layout.maxIcons = newValue }
    }

    /// Shows the space label.
    var showSpaceLabel: Bool {
        get { builtinSpaces.layout.showLabel }
        set { builtinSpaces.layout.showLabel = newValue }
    }

    /// Shows app icons inside a space.
    var showSpaceIcons: Bool {
        get { builtinSpaces.layout.showIcons }
        set { builtinSpaces.layout.showIcons = newValue }
    }

    /// Shows labels only for the active space.
    var showOnlyFocusedLabel: Bool {
        get { builtinSpaces.layout.showOnlyFocusedLabel }
        set { builtinSpaces.layout.showOnlyFocusedLabel = newValue }
    }

    /// Collapses inactive spaces.
    var collapseInactiveSpaces: Bool {
        get { builtinSpaces.layout.collapseInactive }
        set { builtinSpaces.layout.collapseInactive = newValue }
    }

    /// Horizontal padding for collapsed inactive spaces.
    var collapsedSpacePaddingX: CGFloat {
        get { CGFloat(builtinSpaces.layout.collapsedPaddingX) }
        set { builtinSpaces.layout.collapsedPaddingX = Double(newValue) }
    }

    /// Vertical padding for collapsed inactive spaces.
    var collapsedSpacePaddingY: CGFloat {
        get { CGFloat(builtinSpaces.layout.collapsedPaddingY) }
        set { builtinSpaces.layout.collapsedPaddingY = Double(newValue) }
    }

    /// Label font size.
    var spaceTextSize: CGFloat {
        get { CGFloat(builtinSpaces.text.size) }
        set { builtinSpaces.text.size = Double(newValue) }
    }

    /// Label font weight name.
    var spaceTextWeight: String {
        get { builtinSpaces.text.weight }
        set { builtinSpaces.text.weight = newValue }
    }

    /// Active space text color.
    var spaceFocusedTextHex: String {
        get { builtinSpaces.text.focusedColorHex }
        set { builtinSpaces.text.focusedColorHex = newValue }
    }

    /// Inactive space text color.
    var spaceInactiveTextHex: String {
        get { builtinSpaces.text.inactiveColorHex }
        set { builtinSpaces.text.inactiveColorHex = newValue }
    }

    /// Default app icon size.
    var iconSize: CGFloat {
        get { CGFloat(builtinSpaces.icons.size) }
        set { builtinSpaces.icons.size = Double(newValue) }
    }

    /// Gap between app icons.
    var iconSpacing: CGFloat {
        get { CGFloat(builtinSpaces.icons.spacing) }
        set { builtinSpaces.icons.spacing = Double(newValue) }
    }

    /// App icon corner radius.
    var iconCornerRadius: CGFloat {
        get { CGFloat(builtinSpaces.icons.cornerRadius) }
        set { builtinSpaces.icons.cornerRadius = Double(newValue) }
    }

    /// Focused app icon size.
    var focusedAppIconSize: CGFloat {
        get { CGFloat(builtinSpaces.icons.focusedAppSize) }
        set { builtinSpaces.icons.focusedAppSize = Double(newValue) }
    }

    /// Default app icon border width.
    var iconBorderWidth: CGFloat {
        get { CGFloat(builtinSpaces.icons.borderWidth) }
        set { builtinSpaces.icons.borderWidth = Double(newValue) }
    }

    /// Focused app icon border width.
    var focusedAppIconBorderWidth: CGFloat {
        get { CGFloat(builtinSpaces.icons.focusedAppBorderWidth) }
        set { builtinSpaces.icons.focusedAppBorderWidth = Double(newValue) }
    }

    /// Active space background color.
    var spaceActiveBackgroundHex: String {
        get { builtinSpaces.colors.activeBackgroundHex }
        set { builtinSpaces.colors.activeBackgroundHex = newValue }
    }

    /// Inactive space background color.
    var spaceInactiveBackgroundHex: String {
        get { builtinSpaces.colors.inactiveBackgroundHex }
        set { builtinSpaces.colors.inactiveBackgroundHex = newValue }
    }

    /// Active space border color.
    var spaceActiveBorderHex: String {
        get { builtinSpaces.colors.activeBorderHex }
        set { builtinSpaces.colors.activeBorderHex = newValue }
    }

    /// Inactive space border color.
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
        luaPath = ConfigDefaults.luaPath
        watchConfigFile = ConfigDefaults.watchConfigFile

        logToFile = ConfigDefaults.logToFile
        logFilePath = ConfigDefaults.logFilePath

        barHeight = ConfigDefaults.barHeight
        barPaddingX = ConfigDefaults.barPaddingX

        barBackgroundHex = ConfigDefaults.barBackgroundHex
        barBorderHex = ConfigDefaults.barBorderHex
        textColorHex = ConfigDefaults.textColorHex
        focusedAppBorderHex = ConfigDefaults.focusedAppBorderHex

        builtinCPU = ConfigDefaults.builtinCPU
        builtinBattery = ConfigDefaults.builtinBattery
        builtinSpaces = ConfigDefaults.builtinSpaces
        builtinFrontApp = ConfigDefaults.builtinFrontApp
        builtinVolume = ConfigDefaults.builtinVolume
        builtinCalendar = ConfigDefaults.builtinCalendar
        builtinTime = ConfigDefaults.builtinTime
        builtinDate = ConfigDefaults.builtinDate
    }

    /// Captures the current config state.
    private func snapshot() -> ConfigSnapshot {
        ConfigSnapshot(
            widgetsPath: widgetsPath,
            luaPath: luaPath,
            watchConfigFile: watchConfigFile,
            logToFile: logToFile,
            logFilePath: logFilePath,
            barHeight: barHeight,
            barPaddingX: barPaddingX,
            barBackgroundHex: barBackgroundHex,
            barBorderHex: barBorderHex,
            textColorHex: textColorHex,
            focusedAppBorderHex: focusedAppBorderHex,
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

    /// Restores a previous config state.
    private func apply(_ snapshot: ConfigSnapshot) {
        widgetsPath = snapshot.widgetsPath
        luaPath = snapshot.luaPath
        watchConfigFile = snapshot.watchConfigFile

        logToFile = snapshot.logToFile
        logFilePath = snapshot.logFilePath

        barHeight = snapshot.barHeight
        barPaddingX = snapshot.barPaddingX

        barBackgroundHex = snapshot.barBackgroundHex
        barBorderHex = snapshot.barBorderHex
        textColorHex = snapshot.textColorHex
        focusedAppBorderHex = snapshot.focusedAppBorderHex

        builtinCPU = snapshot.builtinCPU
        builtinBattery = snapshot.builtinBattery
        builtinSpaces = snapshot.builtinSpaces
        builtinFrontApp = snapshot.builtinFrontApp
        builtinVolume = snapshot.builtinVolume
        builtinCalendar = snapshot.builtinCalendar
        builtinTime = snapshot.builtinTime
        builtinDate = snapshot.builtinDate

        Logger.configure(logToFile: logToFile, filePath: logFilePath)
    }
}
