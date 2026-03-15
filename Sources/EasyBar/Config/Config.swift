import Foundation
import SwiftUI
import TOMLKit

/// Global EasyBar configuration loaded from disk.
final class Config {

    struct BuiltinWidgetStyle {
        var enabled: Bool
        var position: String
        var order: Int

        var icon: String

        var textColorHex: String?
        var backgroundColorHex: String?
        var borderColorHex: String?

        var borderWidth: Double
        var cornerRadius: Double
        var paddingX: Double
        var paddingY: Double
        var spacing: Double
        var opacity: Double
    }

    struct BatteryBuiltinConfig {
        var style: BuiltinWidgetStyle
        var chargingIcon: String
        var unavailableText: String
        var showPercentage: Bool
    }

    struct VolumeBuiltinConfig {
        var style: BuiltinWidgetStyle
        var mutedIcon: String
        var lowIcon: String
        var highIcon: String
        var showPercentage: Bool
        var minValue: Double
        var maxValue: Double
        var step: Double
    }

    struct DateBuiltinConfig {
        var style: BuiltinWidgetStyle
        var format: String
    }

    struct TimeBuiltinConfig {
        var style: BuiltinWidgetStyle
        var format: String
    }

    struct CalendarBuiltinConfig {
        var style: BuiltinWidgetStyle
        var format: String
        var days: Int
        var emptyText: String

        // Anchor layout in the bar.
        // "item"   => icon + single text using `format`
        // "stack"  => icon + 2 text rows using `topFormat` and `bottomFormat`
        // "inline" => icon + 2 text columns using `topFormat` and `bottomFormat`
        var layout: String
        var topFormat: String
        var bottomFormat: String
        var lineSpacing: Double
        var topTextColorHex: String?
        var bottomTextColorHex: String?

        // Popup styling.
        var popupBackgroundColorHex: String
        var popupBorderColorHex: String
        var popupBorderWidth: Double
        var popupCornerRadius: Double
        var popupPaddingX: Double
        var popupPaddingY: Double
        var popupSpacing: Double
        var popupItemIndent: Double
        var popupSectionTitleColorHex: String
        var popupItemColorHex: String
        var popupEmptyColorHex: String
    }

    static let shared = Config()

    var barHeight: CGFloat = 36
    var barPadding: CGFloat = 10

    var spaceSpacing: CGFloat = 8
    var hideEmptySpaces: Bool = true
    var spacePaddingX: CGFloat = 10
    var spacePaddingY: CGFloat = 6
    var spaceCornerRadius: CGFloat = 8
    var spaceFocusedScale: CGFloat = 1.0
    var spaceInactiveOpacity: Double = 0.85
    var maxIconsPerSpace: Int = 4
    var showSpaceNumber: Bool = true
    var showSpaceIcons: Bool = true
    var showOnlyFocusedLabel: Bool = false
    var collapseInactiveSpaces: Bool = false
    var collapsedSpacePaddingX: CGFloat = 6
    var collapsedSpacePaddingY: CGFloat = 4

    var spaceTextSize: CGFloat = 12
    var spaceTextWeight: String = "semibold"
    var spaceFocusedTextHex: String = "#ffffff"
    var spaceInactiveTextHex: String = "#d0d0d0"

    var iconSize: CGFloat = 14
    var iconSpacing: CGFloat = 4
    var iconCornerRadius: CGFloat = 3
    var focusedIconSize: CGFloat = 18
    var iconBorderWidth: CGFloat = 1
    var focusedIconBorderWidth: CGFloat = 1

    var barBackgroundHex: String = "#111111"
    var barBorderHex: String = "#222222"
    var textColorHex: String = "#ffffff"
    var spaceActiveBackgroundHex: String = "#2b2b2b"
    var spaceInactiveBackgroundHex: String = "#1a1a1a"
    var spaceActiveBorderHex: String = "#444444"
    var spaceInactiveBorderHex: String = "#00000000"
    var focusedAppBorderHex: String = "#ff3b30"

    var luaPath: String = "/usr/local/bin/lua"

    var builtinBattery = BatteryBuiltinConfig(
        style: BuiltinWidgetStyle(
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
        chargingIcon: "⚡️",
        unavailableText: "n/a",
        showPercentage: true
    )

    var builtinVolume = VolumeBuiltinConfig(
        style: BuiltinWidgetStyle(
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
        step: 1
    )

    var builtinDate = DateBuiltinConfig(
        style: BuiltinWidgetStyle(
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

    var builtinTime = TimeBuiltinConfig(
        style: BuiltinWidgetStyle(
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

    var builtinCalendar = CalendarBuiltinConfig(
        style: BuiltinWidgetStyle(
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

    /// Absolute path to the widgets directory.
    var widgetsPath: String = ""

    private init() {
        resetDerivedDefaults()
        load()
    }

    /// Reloads configuration from disk.
    func reload() {
        Logger.info("reloading configuration")
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

    /// Restores defaults that are derived from the user's home directory.
    private func resetDerivedDefaults() {
        widgetsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/easybar/widgets")
            .path
    }

    /// Loads configuration from disk.
    private func load() {

        let resolvedConfigPath = configPath

        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedConfigPath)),
            let text = String(data: data, encoding: .utf8)
        else {
            Logger.info("using default configuration from \(resolvedConfigPath)")
            applyEnvironmentOverrides()
            return
        }

        do {
            let toml = try TOMLTable(string: text)

            if let paths = toml["paths"]?.table {
                if let configuredWidgetsPath = paths["widgets"]?.string,
                   !configuredWidgetsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    widgetsPath = NSString(string: configuredWidgetsPath).expandingTildeInPath
                }
            }

            if let bar = toml["bar"]?.table {
                barHeight = CGFloat(bar["height"]?.int ?? Int(barHeight))
                barPadding = CGFloat(bar["padding"]?.int ?? Int(barPadding))
            }

            if let spaces = toml["spaces"]?.table {
                spaceSpacing = CGFloat(spaces["spacing"]?.int ?? Int(spaceSpacing))
                hideEmptySpaces = spaces["hide_empty"]?.bool ?? hideEmptySpaces
                spacePaddingX = CGFloat(spaces["padding_x"]?.int ?? Int(spacePaddingX))
                spacePaddingY = CGFloat(spaces["padding_y"]?.int ?? Int(spacePaddingY))
                spaceCornerRadius = CGFloat(spaces["corner_radius"]?.int ?? Int(spaceCornerRadius))

                if let focusedScale = spaces["focused_scale"]?.double {
                    spaceFocusedScale = CGFloat(focusedScale)
                } else {
                    spaceFocusedScale = 1.0
                }

                spaceInactiveOpacity = spaces["inactive_opacity"]?.double ?? spaceInactiveOpacity
                maxIconsPerSpace = spaces["max_icons"]?.int ?? maxIconsPerSpace
                showSpaceNumber = spaces["show_number"]?.bool ?? showSpaceNumber
                showSpaceIcons = spaces["show_icons"]?.bool ?? showSpaceIcons
                showOnlyFocusedLabel = spaces["show_only_focused_label"]?.bool ?? showOnlyFocusedLabel
                collapseInactiveSpaces = spaces["collapse_inactive"]?.bool ?? collapseInactiveSpaces
                collapsedSpacePaddingX = CGFloat(spaces["collapsed_padding_x"]?.int ?? Int(collapsedSpacePaddingX))
                collapsedSpacePaddingY = CGFloat(spaces["collapsed_padding_y"]?.int ?? Int(collapsedSpacePaddingY))
            }

            if let spaceText = toml["space_text"]?.table {
                spaceTextSize = CGFloat(spaceText["size"]?.int ?? Int(spaceTextSize))
                spaceTextWeight = spaceText["weight"]?.string ?? spaceTextWeight
                spaceFocusedTextHex = spaceText["focused_color"]?.string ?? spaceFocusedTextHex
                spaceInactiveTextHex = spaceText["inactive_color"]?.string ?? spaceInactiveTextHex
            }

            if let icons = toml["icons"]?.table {
                iconSize = CGFloat(icons["size"]?.int ?? Int(iconSize))
                iconSpacing = CGFloat(icons["spacing"]?.int ?? Int(iconSpacing))
                iconCornerRadius = CGFloat(icons["corner_radius"]?.int ?? Int(iconCornerRadius))
                focusedIconSize = CGFloat(icons["focused_size"]?.int ?? Int(focusedIconSize))
                iconBorderWidth = CGFloat(icons["border_width"]?.int ?? Int(iconBorderWidth))
                focusedIconBorderWidth = CGFloat(icons["focused_border_width"]?.int ?? Int(focusedIconBorderWidth))
            }

            if let colors = toml["colors"]?.table {
                barBackgroundHex = colors["bar_background"]?.string ?? barBackgroundHex
                barBorderHex = colors["bar_border"]?.string ?? barBorderHex
                textColorHex = colors["text_color"]?.string ?? textColorHex
                spaceActiveBackgroundHex = colors["space_active_background"]?.string ?? spaceActiveBackgroundHex
                spaceInactiveBackgroundHex = colors["space_inactive_background"]?.string ?? spaceInactiveBackgroundHex
                spaceActiveBorderHex = colors["space_active_border"]?.string ?? spaceActiveBorderHex
                spaceInactiveBorderHex = colors["space_inactive_border"]?.string ?? spaceInactiveBorderHex
                focusedAppBorderHex = colors["focused_app_border"]?.string ?? focusedAppBorderHex
            }

            if let lua = toml["lua"]?.table {
                luaPath = lua["path"]?.string ?? luaPath
            }

            if let builtins = toml["builtins"]?.table {

                if let battery = builtins["battery"]?.table {
                    let style = parseBuiltinStyle(from: battery, fallback: builtinBattery.style)

                    builtinBattery = BatteryBuiltinConfig(
                        style: style,
                        chargingIcon: battery["charging_icon"]?.string ?? builtinBattery.chargingIcon,
                        unavailableText: battery["unavailable_text"]?.string ?? builtinBattery.unavailableText,
                        showPercentage: battery["show_percentage"]?.bool ?? builtinBattery.showPercentage
                    )
                }

                if let volume = builtins["volume"]?.table {
                    let style = parseBuiltinStyle(from: volume, fallback: builtinVolume.style)

                    builtinVolume = VolumeBuiltinConfig(
                        style: style,
                        mutedIcon: volume["muted_icon"]?.string ?? builtinVolume.mutedIcon,
                        lowIcon: volume["low_icon"]?.string ?? builtinVolume.lowIcon,
                        highIcon: volume["high_icon"]?.string ?? builtinVolume.highIcon,
                        showPercentage: volume["show_percentage"]?.bool ?? builtinVolume.showPercentage,
                        minValue: volume["min"]?.double ?? builtinVolume.minValue,
                        maxValue: volume["max"]?.double ?? builtinVolume.maxValue,
                        step: volume["step"]?.double ?? builtinVolume.step
                    )
                }

                if let date = builtins["date"]?.table {
                    let style = parseBuiltinStyle(from: date, fallback: builtinDate.style)

                    builtinDate = DateBuiltinConfig(
                        style: style,
                        format: date["format"]?.string ?? builtinDate.format
                    )
                }

                if let time = builtins["time"]?.table {
                    let style = parseBuiltinStyle(from: time, fallback: builtinTime.style)

                    builtinTime = TimeBuiltinConfig(
                        style: style,
                        format: time["format"]?.string ?? builtinTime.format
                    )
                }

                if let calendar = builtins["calendar"]?.table {
                    let style = parseBuiltinStyle(from: calendar, fallback: builtinCalendar.style)

                    builtinCalendar = CalendarBuiltinConfig(
                        style: style,
                        format: calendar["format"]?.string ?? builtinCalendar.format,
                        days: max(1, calendar["days"]?.int ?? builtinCalendar.days),
                        emptyText: calendar["empty_text"]?.string ?? builtinCalendar.emptyText,
                        layout: normalizedCalendarLayout(calendar["layout"]?.string ?? builtinCalendar.layout),
                        topFormat: calendar["top_format"]?.string ?? builtinCalendar.topFormat,
                        bottomFormat: calendar["bottom_format"]?.string ?? builtinCalendar.bottomFormat,
                        lineSpacing: calendar["line_spacing"]?.double ?? builtinCalendar.lineSpacing,
                        topTextColorHex: calendar["top_text_color"]?.string ?? builtinCalendar.topTextColorHex,
                        bottomTextColorHex: calendar["bottom_text_color"]?.string ?? builtinCalendar.bottomTextColorHex,
                        popupBackgroundColorHex: calendar["popup_background_color"]?.string ?? builtinCalendar.popupBackgroundColorHex,
                        popupBorderColorHex: calendar["popup_border_color"]?.string ?? builtinCalendar.popupBorderColorHex,
                        popupBorderWidth: calendar["popup_border_width"]?.double ?? builtinCalendar.popupBorderWidth,
                        popupCornerRadius: calendar["popup_corner_radius"]?.double ?? builtinCalendar.popupCornerRadius,
                        popupPaddingX: calendar["popup_padding_x"]?.double ?? builtinCalendar.popupPaddingX,
                        popupPaddingY: calendar["popup_padding_y"]?.double ?? builtinCalendar.popupPaddingY,
                        popupSpacing: calendar["popup_spacing"]?.double ?? builtinCalendar.popupSpacing,
                        popupItemIndent: calendar["popup_item_indent"]?.double ?? builtinCalendar.popupItemIndent,
                        popupSectionTitleColorHex: calendar["popup_section_title_color"]?.string ?? builtinCalendar.popupSectionTitleColorHex,
                        popupItemColorHex: calendar["popup_item_color"]?.string ?? builtinCalendar.popupItemColorHex,
                        popupEmptyColorHex: calendar["popup_empty_color"]?.string ?? builtinCalendar.popupEmptyColorHex
                    )
                }
            }

        } catch {
            Logger.info("config parse error: \(error)")
        }

        applyEnvironmentOverrides()
    }

    /// Applies environment variable overrides after config loading.
    private func applyEnvironmentOverrides() {
        if let widgetsOverride = ProcessInfo.processInfo.environment["EASYBAR_WIDGETS_PATH"],
           !widgetsOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            widgetsPath = NSString(string: widgetsOverride).expandingTildeInPath
        }
    }

    private func parseBuiltinStyle(
        from table: TOMLTable,
        fallback: BuiltinWidgetStyle
    ) -> BuiltinWidgetStyle {
        BuiltinWidgetStyle(
            enabled: table["enabled"]?.bool ?? fallback.enabled,
            position: normalizedPosition(table["position"]?.string ?? fallback.position),
            order: table["order"]?.int ?? fallback.order,
            icon: table["icon"]?.string ?? fallback.icon,
            textColorHex: table["text_color"]?.string ?? fallback.textColorHex,
            backgroundColorHex: table["background_color"]?.string ?? fallback.backgroundColorHex,
            borderColorHex: table["border_color"]?.string ?? fallback.borderColorHex,
            borderWidth: table["border_width"]?.double ?? fallback.borderWidth,
            cornerRadius: table["corner_radius"]?.double ?? fallback.cornerRadius,
            paddingX: table["padding_x"]?.double ?? fallback.paddingX,
            paddingY: table["padding_y"]?.double ?? fallback.paddingY,
            spacing: table["spacing"]?.double ?? fallback.spacing,
            opacity: table["opacity"]?.double ?? fallback.opacity
        )
    }

    private func normalizedPosition(_ value: String) -> String {
        switch value {
        case "left", "center", "right":
            return value
        default:
            return "right"
        }
    }

    private func normalizedCalendarLayout(_ value: String) -> String {
        switch value {
        case "item", "stack", "inline":
            return value
        default:
            return "item"
        }
    }
}
