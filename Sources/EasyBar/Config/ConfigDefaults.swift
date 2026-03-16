import Foundation
import SwiftUI

enum ConfigDefaults {

    static let barHeight: CGFloat = 36
    static let barPadding: CGFloat = 10

    static let spaceSpacing: CGFloat = 8
    static let hideEmptySpaces = true
    static let spacePaddingX: CGFloat = 10
    static let spacePaddingY: CGFloat = 6
    static let spaceCornerRadius: CGFloat = 8
    static let spaceFocusedScale: CGFloat = 1.0
    static let spaceInactiveOpacity: Double = 0.85
    static let maxIconsPerSpace = 4
    static let showSpaceNumber = true
    static let showSpaceIcons = true
    static let showOnlyFocusedLabel = false
    static let collapseInactiveSpaces = false
    static let collapsedSpacePaddingX: CGFloat = 6
    static let collapsedSpacePaddingY: CGFloat = 4

    static let spaceTextSize: CGFloat = 12
    static let spaceTextWeight = "semibold"
    static let spaceFocusedTextHex = "#ffffff"
    static let spaceInactiveTextHex = "#d0d0d0"

    static let iconSize: CGFloat = 14
    static let iconSpacing: CGFloat = 4
    static let iconCornerRadius: CGFloat = 3
    static let focusedIconSize: CGFloat = 18
    static let iconBorderWidth: CGFloat = 1
    static let focusedIconBorderWidth: CGFloat = 1

    static let barBackgroundHex = "#111111"
    static let barBorderHex = "#222222"
    static let textColorHex = "#ffffff"
    static let spaceActiveBackgroundHex = "#2b2b2b"
    static let spaceInactiveBackgroundHex = "#1a1a1a"
    static let spaceActiveBorderHex = "#444444"
    static let spaceInactiveBorderHex = "#00000000"
    static let focusedAppBorderHex = "#ff3b30"

    static let luaPath = "/usr/local/bin/lua"

    static let logToFile = false
    static let logFilePath = "~/Library/Logs/EasyBar.log"

    static let builtinBattery = Config.BatteryBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: true,
            position: "right",
            order: 10,
            icon: "🔋",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            opacity: 1
        ),
        unavailableText: "n/a",
        showPercentage: true
    )

    static let builtinSpaces = Config.SpacesBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: true,
            position: "left",
            order: 10,
            icon: "",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 0,
            paddingY: 0,
            spacing: 0,
            opacity: 1
        )
    )

    static let builtinFrontApp = Config.FrontAppBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: false,
            position: "left",
            order: 15,
            icon: "􀈔",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            opacity: 1
        ),
        showIcon: true,
        showName: true,
        fallbackText: "No App",
        iconSize: 14,
        iconCornerRadius: 4
    )

    static let builtinVolume = Config.VolumeBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: true,
            position: "right",
            order: 20,
            icon: "🔊",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 8,
            paddingY: 4,
            spacing: 8,
            opacity: 1
        ),
        mutedIcon: "🔇",
        lowIcon: "🔉",
        highIcon: "🔊",
        showPercentage: true,
        minValue: 0,
        maxValue: 100,
        step: 1,
        expandToSliderOnHover: false,
        sliderWidth: 140
    )

    static let builtinDate = Config.DateBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: true,
            position: "right",
            order: 30,
            icon: "📅",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            opacity: 1
        ),
        format: "yyyy-MM-dd"
    )

    static let builtinTime = Config.TimeBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: true,
            position: "right",
            order: 40,
            icon: "🕒",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            opacity: 1
        ),
        format: "HH:mm"
    )

    static let builtinCalendar = Config.CalendarBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: true,
            position: "right",
            order: 50,
            icon: "🗓",
            textColorHex: nil,
            backgroundColorHex: nil,
            borderColorHex: nil,
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            opacity: 1
        ),
        format: "EEE, MMM d",
        days: 3,
        emptyText: "No upcoming events",
        layout: "item",
        topFormat: "HH:mm",
        bottomFormat: "MMMM, d",
        lineSpacing: 0,
        topTextColorHex: nil,
        bottomTextColorHex: nil,
        showBirthdays: true,
        birthdaysTitle: "Birthdays",
        birthdaysDateFormat: "dd.MM.yyyy",
        birthdaysShowAge: false,
        popupBackgroundColorHex: "#1a1a1a",
        popupBorderColorHex: "#333333",
        popupBorderWidth: 1,
        popupCornerRadius: 10,
        popupPaddingX: 10,
        popupPaddingY: 8,
        popupSpacing: 8,
        popupItemIndent: 8,
        popupSectionTitleColorHex: "#ffffff",
        popupItemColorHex: "#d0d0d0",
        popupEmptyColorHex: "#c0c0c0"
    )
}
