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

    var builtinBattery: BatteryBuiltinConfig = ConfigDefaults.builtinBattery
    var builtinVolume: VolumeBuiltinConfig = ConfigDefaults.builtinVolume
    var builtinDate: DateBuiltinConfig = ConfigDefaults.builtinDate
    var builtinTime: TimeBuiltinConfig = ConfigDefaults.builtinTime
    var builtinCalendar: CalendarBuiltinConfig = ConfigDefaults.builtinCalendar

    /// Absolute path to the widgets directory.
    var widgetsPath: String = ""

    private init() {
        resetDerivedDefaults()
        load()
    }

    /// Reloads configuration from disk.
    func reload() {
        Logger.info("reloading configuration")
        resetAllToDefaults()
        resetDerivedDefaults()
        load()
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

        builtinBattery = ConfigDefaults.builtinBattery
        builtinVolume = ConfigDefaults.builtinVolume
        builtinDate = ConfigDefaults.builtinDate
        builtinTime = ConfigDefaults.builtinTime
        builtinCalendar = ConfigDefaults.builtinCalendar
    }
}
