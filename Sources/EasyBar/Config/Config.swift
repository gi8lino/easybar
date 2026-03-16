import Foundation
import SwiftUI

/// Global EasyBar configuration loaded from disk.
final class Config {

    static let shared = Config()

    var barHeight: CGFloat = ConfigDefaults.barHeight
    var barPadding: CGFloat = ConfigDefaults.barPadding

    var spaceSpacing: CGFloat = ConfigDefaults.spaceSpacing
    var hideEmptySpaces: Bool = ConfigDefaults.hideEmptySpaces
    var spacePaddingX: CGFloat = ConfigDefaults.spacePaddingX
    var spacePaddingY: CGFloat = ConfigDefaults.spacePaddingY
    var spaceCornerRadius: CGFloat = ConfigDefaults.spaceCornerRadius
    var spaceFocusedScale: CGFloat = ConfigDefaults.spaceFocusedScale
    var spaceInactiveOpacity: Double = ConfigDefaults.spaceInactiveOpacity
    var maxIconsPerSpace: Int = ConfigDefaults.maxIconsPerSpace
    var showSpaceNumber: Bool = ConfigDefaults.showSpaceNumber
    var showSpaceIcons: Bool = ConfigDefaults.showSpaceIcons
    var showOnlyFocusedLabel: Bool = ConfigDefaults.showOnlyFocusedLabel
    var collapseInactiveSpaces: Bool = ConfigDefaults.collapseInactiveSpaces
    var collapsedSpacePaddingX: CGFloat = ConfigDefaults.collapsedSpacePaddingX
    var collapsedSpacePaddingY: CGFloat = ConfigDefaults.collapsedSpacePaddingY

    var spaceTextSize: CGFloat = ConfigDefaults.spaceTextSize
    var spaceTextWeight: String = ConfigDefaults.spaceTextWeight
    var spaceFocusedTextHex: String = ConfigDefaults.spaceFocusedTextHex
    var spaceInactiveTextHex: String = ConfigDefaults.spaceInactiveTextHex

    var iconSize: CGFloat = ConfigDefaults.iconSize
    var iconSpacing: CGFloat = ConfigDefaults.iconSpacing
    var iconCornerRadius: CGFloat = ConfigDefaults.iconCornerRadius
    var focusedIconSize: CGFloat = ConfigDefaults.focusedIconSize
    var iconBorderWidth: CGFloat = ConfigDefaults.iconBorderWidth
    var focusedIconBorderWidth: CGFloat = ConfigDefaults.focusedIconBorderWidth

    var barBackgroundHex: String = ConfigDefaults.barBackgroundHex
    var barBorderHex: String = ConfigDefaults.barBorderHex
    var textColorHex: String = ConfigDefaults.textColorHex
    var spaceActiveBackgroundHex: String = ConfigDefaults.spaceActiveBackgroundHex
    var spaceInactiveBackgroundHex: String = ConfigDefaults.spaceInactiveBackgroundHex
    var spaceActiveBorderHex: String = ConfigDefaults.spaceActiveBorderHex
    var spaceInactiveBorderHex: String = ConfigDefaults.spaceInactiveBorderHex
    var focusedAppBorderHex: String = ConfigDefaults.focusedAppBorderHex

    var luaPath: String = ConfigDefaults.luaPath

    var logToFile: Bool = ConfigDefaults.logToFile
    var logFilePath: String = ConfigDefaults.logFilePath

    var builtinBattery: BatteryBuiltinConfig = ConfigDefaults.builtinBattery
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
        } catch {
            // Keep old runtime config on reload failure.
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

        spaceSpacing = ConfigDefaults.spaceSpacing
        hideEmptySpaces = ConfigDefaults.hideEmptySpaces
        spacePaddingX = ConfigDefaults.spacePaddingX
        spacePaddingY = ConfigDefaults.spacePaddingY
        spaceCornerRadius = ConfigDefaults.spaceCornerRadius
        spaceFocusedScale = ConfigDefaults.spaceFocusedScale
        spaceInactiveOpacity = ConfigDefaults.spaceInactiveOpacity
        maxIconsPerSpace = ConfigDefaults.maxIconsPerSpace
        showSpaceNumber = ConfigDefaults.showSpaceNumber
        showSpaceIcons = ConfigDefaults.showSpaceIcons
        showOnlyFocusedLabel = ConfigDefaults.showOnlyFocusedLabel
        collapseInactiveSpaces = ConfigDefaults.collapseInactiveSpaces
        collapsedSpacePaddingX = ConfigDefaults.collapsedSpacePaddingX
        collapsedSpacePaddingY = ConfigDefaults.collapsedSpacePaddingY

        spaceTextSize = ConfigDefaults.spaceTextSize
        spaceTextWeight = ConfigDefaults.spaceTextWeight
        spaceFocusedTextHex = ConfigDefaults.spaceFocusedTextHex
        spaceInactiveTextHex = ConfigDefaults.spaceInactiveTextHex

        iconSize = ConfigDefaults.iconSize
        iconSpacing = ConfigDefaults.iconSpacing
        iconCornerRadius = ConfigDefaults.iconCornerRadius
        focusedIconSize = ConfigDefaults.focusedIconSize
        iconBorderWidth = ConfigDefaults.iconBorderWidth
        focusedIconBorderWidth = ConfigDefaults.focusedIconBorderWidth

        barBackgroundHex = ConfigDefaults.barBackgroundHex
        barBorderHex = ConfigDefaults.barBorderHex
        textColorHex = ConfigDefaults.textColorHex
        spaceActiveBackgroundHex = ConfigDefaults.spaceActiveBackgroundHex
        spaceInactiveBackgroundHex = ConfigDefaults.spaceInactiveBackgroundHex
        spaceActiveBorderHex = ConfigDefaults.spaceActiveBorderHex
        spaceInactiveBorderHex = ConfigDefaults.spaceInactiveBorderHex
        focusedAppBorderHex = ConfigDefaults.focusedAppBorderHex

        luaPath = ConfigDefaults.luaPath

        logToFile = ConfigDefaults.logToFile
        logFilePath = ConfigDefaults.logFilePath

        builtinBattery = ConfigDefaults.builtinBattery
        builtinVolume = ConfigDefaults.builtinVolume
        builtinDate = ConfigDefaults.builtinDate
        builtinTime = ConfigDefaults.builtinTime
        builtinCalendar = ConfigDefaults.builtinCalendar
    }

    private func snapshot() -> ConfigSnapshot {
        ConfigSnapshot(
            barHeight: barHeight,
            barPadding: barPadding,

            spaceSpacing: spaceSpacing,
            hideEmptySpaces: hideEmptySpaces,
            spacePaddingX: spacePaddingX,
            spacePaddingY: spacePaddingY,
            spaceCornerRadius: spaceCornerRadius,
            spaceFocusedScale: spaceFocusedScale,
            spaceInactiveOpacity: spaceInactiveOpacity,
            maxIconsPerSpace: maxIconsPerSpace,
            showSpaceNumber: showSpaceNumber,
            showSpaceIcons: showSpaceIcons,
            showOnlyFocusedLabel: showOnlyFocusedLabel,
            collapseInactiveSpaces: collapseInactiveSpaces,
            collapsedSpacePaddingX: collapsedSpacePaddingX,
            collapsedSpacePaddingY: collapsedSpacePaddingY,

            spaceTextSize: spaceTextSize,
            spaceTextWeight: spaceTextWeight,
            spaceFocusedTextHex: spaceFocusedTextHex,
            spaceInactiveTextHex: spaceInactiveTextHex,

            iconSize: iconSize,
            iconSpacing: iconSpacing,
            iconCornerRadius: iconCornerRadius,
            focusedIconSize: focusedIconSize,
            iconBorderWidth: iconBorderWidth,
            focusedIconBorderWidth: focusedIconBorderWidth,

            barBackgroundHex: barBackgroundHex,
            barBorderHex: barBorderHex,
            textColorHex: textColorHex,
            spaceActiveBackgroundHex: spaceActiveBackgroundHex,
            spaceInactiveBackgroundHex: spaceInactiveBackgroundHex,
            spaceActiveBorderHex: spaceActiveBorderHex,
            spaceInactiveBorderHex: spaceInactiveBorderHex,
            focusedAppBorderHex: focusedAppBorderHex,

            luaPath: luaPath,

            logToFile: logToFile,
            logFilePath: logFilePath,

            builtinBattery: builtinBattery,
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

        spaceSpacing = snapshot.spaceSpacing
        hideEmptySpaces = snapshot.hideEmptySpaces
        spacePaddingX = snapshot.spacePaddingX
        spacePaddingY = snapshot.spacePaddingY
        spaceCornerRadius = snapshot.spaceCornerRadius
        spaceFocusedScale = snapshot.spaceFocusedScale
        spaceInactiveOpacity = snapshot.spaceInactiveOpacity
        maxIconsPerSpace = snapshot.maxIconsPerSpace
        showSpaceNumber = snapshot.showSpaceNumber
        showSpaceIcons = snapshot.showSpaceIcons
        showOnlyFocusedLabel = snapshot.showOnlyFocusedLabel
        collapseInactiveSpaces = snapshot.collapseInactiveSpaces
        collapsedSpacePaddingX = snapshot.collapsedSpacePaddingX
        collapsedSpacePaddingY = snapshot.collapsedSpacePaddingY

        spaceTextSize = snapshot.spaceTextSize
        spaceTextWeight = snapshot.spaceTextWeight
        spaceFocusedTextHex = snapshot.spaceFocusedTextHex
        spaceInactiveTextHex = snapshot.spaceInactiveTextHex

        iconSize = snapshot.iconSize
        iconSpacing = snapshot.iconSpacing
        iconCornerRadius = snapshot.iconCornerRadius
        focusedIconSize = snapshot.focusedIconSize
        iconBorderWidth = snapshot.iconBorderWidth
        focusedIconBorderWidth = snapshot.focusedIconBorderWidth

        barBackgroundHex = snapshot.barBackgroundHex
        barBorderHex = snapshot.barBorderHex
        textColorHex = snapshot.textColorHex
        spaceActiveBackgroundHex = snapshot.spaceActiveBackgroundHex
        spaceInactiveBackgroundHex = snapshot.spaceInactiveBackgroundHex
        spaceActiveBorderHex = snapshot.spaceActiveBorderHex
        spaceInactiveBorderHex = snapshot.spaceInactiveBorderHex
        focusedAppBorderHex = snapshot.focusedAppBorderHex

        luaPath = snapshot.luaPath

        logToFile = snapshot.logToFile
        logFilePath = snapshot.logFilePath

        builtinBattery = snapshot.builtinBattery
        builtinVolume = snapshot.builtinVolume
        builtinDate = snapshot.builtinDate
        builtinTime = snapshot.builtinTime
        builtinCalendar = snapshot.builtinCalendar

        widgetsPath = snapshot.widgetsPath

        Logger.configure(logToFile: logToFile, filePath: logFilePath)
    }
}
