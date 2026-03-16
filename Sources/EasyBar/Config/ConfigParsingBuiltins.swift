import Foundation
import TOMLKit

extension Config {

    func parseBuiltins(from toml: TOMLTable) {
        guard let builtins = toml["builtins"]?.table else { return }

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
                step: volume["step"]?.double ?? builtinVolume.step,
                expandToSliderOnHover: volume["expand_to_slider_on_hover"]?.bool ?? builtinVolume.expandToSliderOnHover,
                sliderWidth: volume["slider_width"]?.double ?? builtinVolume.sliderWidth
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
                showBirthdays: calendar["show_birthdays"]?.bool ?? builtinCalendar.showBirthdays,
                birthdaysTitle: calendar["birthdays_title"]?.string ?? builtinCalendar.birthdaysTitle,
                birthdaysDateFormat: calendar["birthdays_date_format"]?.string ?? builtinCalendar.birthdaysDateFormat,
                birthdaysShowAge: calendar["birthdays_show_age"]?.bool ?? builtinCalendar.birthdaysShowAge,
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

    func parseBuiltinStyle(
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

    func normalizedPosition(_ value: String) -> String {
        switch value {
        case "left", "center", "right":
            return value
        default:
            return "right"
        }
    }

    func normalizedCalendarLayout(_ value: String) -> String {
        switch value {
        case "item", "stack", "inline":
            return value
        default:
            return "item"
        }
    }
}
