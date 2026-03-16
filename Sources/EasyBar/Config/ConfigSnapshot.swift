import Foundation
import SwiftUI

struct ConfigSnapshot {
    let barHeight: CGFloat
    let barPadding: CGFloat

    let spaceSpacing: CGFloat
    let hideEmptySpaces: Bool
    let spacePaddingX: CGFloat
    let spacePaddingY: CGFloat
    let spaceCornerRadius: CGFloat
    let spaceFocusedScale: CGFloat
    let spaceInactiveOpacity: Double
    let maxIconsPerSpace: Int
    let showSpaceNumber: Bool
    let showSpaceIcons: Bool
    let showOnlyFocusedLabel: Bool
    let collapseInactiveSpaces: Bool
    let collapsedSpacePaddingX: CGFloat
    let collapsedSpacePaddingY: CGFloat

    let spaceTextSize: CGFloat
    let spaceTextWeight: String
    let spaceFocusedTextHex: String
    let spaceInactiveTextHex: String

    let iconSize: CGFloat
    let iconSpacing: CGFloat
    let iconCornerRadius: CGFloat
    let focusedIconSize: CGFloat
    let iconBorderWidth: CGFloat
    let focusedIconBorderWidth: CGFloat

    let barBackgroundHex: String
    let barBorderHex: String
    let textColorHex: String
    let spaceActiveBackgroundHex: String
    let spaceInactiveBackgroundHex: String
    let spaceActiveBorderHex: String
    let spaceInactiveBorderHex: String
    let focusedAppBorderHex: String

    let luaPath: String

    let logToFile: Bool
    let logFilePath: String

    let builtinBattery: Config.BatteryBuiltinConfig
    let builtinVolume: Config.VolumeBuiltinConfig
    let builtinDate: Config.DateBuiltinConfig
    let builtinTime: Config.TimeBuiltinConfig
    let builtinCalendar: Config.CalendarBuiltinConfig

    let widgetsPath: String
}
