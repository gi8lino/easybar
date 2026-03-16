import Foundation
import SwiftUI

enum ConfigDefaults {

    static let barHeight: CGFloat = 36
    static let barPadding: CGFloat = 10

    static let barBackgroundHex = "#111111"
    static let barBorderHex = "#222222"
    static let textColorHex = "#ffffff"
    static let focusedAppBorderHex = "#ff3b30"

    static let luaPath = "/usr/local/bin/lua"

    static let logToFile = false
    static let logFilePath = "~/Library/Logs/EasyBar.log"

    static let builtinCPU = Config.CPUBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            enabled: false,
            position: "right",
            order: 60,
            icon: "󰍛",
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
        content: .init(
            label: "CPU",
            historySize: 10,
            lineWidth: 1.8,
            colorHex: "#a6da95"
        )
    )

    static let builtinBattery = Config.BatteryBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
            enabled: false,
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
        content: .init(
            unavailableText: "n/a",
            showPercentage: true
        )
    )

    static let builtinSpaces = Config.SpacesBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
            enabled: false,
            position: "left",
            order: 10,
            icon: "",
            textColorHex: nil,
            backgroundColorHex: "#00000000",
            borderColorHex: "#00000000",
            borderWidth: 0,
            cornerRadius: 0,
            paddingX: 0,
            paddingY: 0,
            spacing: 0,
            opacity: 1
        ),
        layout: .init(
            spacing: 8,
            hideEmpty: true,
            paddingX: 10,
            paddingY: 6,
            marginX: 0,
            marginY: 0,
            cornerRadius: 8,
            focusedCornerRadius: 8,
            focusedScale: 1.0,
            inactiveOpacity: 0.85,
            maxIcons: 4,
            showNumber: true,
            showIcons: true,
            showOnlyFocusedLabel: false,
            collapseInactive: false,
            collapsedPaddingX: 6,
            collapsedPaddingY: 4
        ),
        text: .init(
            size: 12,
            weight: "semibold",
            focusedColorHex: "#ffffff",
            inactiveColorHex: "#d0d0d0"
        ),
        icons: .init(
            size: 14,
            spacing: 4,
            cornerRadius: 3,
            focusedSize: 18,
            borderWidth: 1,
            focusedBorderWidth: 1
        ),
        colors: .init(
            activeBackgroundHex: "#2b2b2b",
            inactiveBackgroundHex: "#1a1a1a",
            activeBorderHex: "#444444",
            inactiveBorderHex: "#00000000"
        )
    )

    static let builtinFrontApp = Config.FrontAppBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
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
        content: .init(
            showIcon: true,
            showName: true,
            fallbackText: "No App",
            iconSize: 14,
            iconCornerRadius: 4
        )
    )

    static let builtinVolume = Config.VolumeBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
            enabled: false,
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
        content: .init(
            mutedIcon: "🔇",
            lowIcon: "🔉",
            highIcon: "🔊",
            showPercentage: true,
            minValue: 0,
            maxValue: 100,
            step: 1
        ),
        slider: .init(
            expandToSliderOnHover: false,
            width: 140
        )
    )

    static let builtinDate = Config.DateBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
            enabled: false,
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
        content: .init(
            format: "yyyy-MM-dd"
        )
    )

    static let builtinTime = Config.TimeBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
            enabled: false,
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
        content: .init(
            format: "HH:mm"
        )
    )

    static let builtinCalendar = Config.CalendarBuiltinConfig(
        style: Config.BuiltinWidgetStyle(
            // Builtins are off unless explicitly configured.
            enabled: false,
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
        anchor: .init(
            format: "EEE, MMM d",
            layout: "item",
            topFormat: "HH:mm",
            bottomFormat: "MMMM, d",
            lineSpacing: 0,
            topTextColorHex: nil,
            bottomTextColorHex: nil
        ),
        events: .init(
            days: 3,
            emptyText: "No upcoming events"
        ),
        birthdays: .init(
            show: true,
            title: "Birthdays",
            dateFormat: "dd.MM.yyyy",
            showAge: false
        ),
        popup: .init(
            backgroundColorHex: "#1a1a1a",
            borderColorHex: "#333333",
            borderWidth: 1,
            cornerRadius: 10,
            paddingX: 10,
            paddingY: 8,
            spacing: 8,
            itemIndent: 8,
            sectionTitleColorHex: "#ffffff",
            itemColorHex: "#d0d0d0",
            emptyColorHex: "#c0c0c0"
        )
    )
}
