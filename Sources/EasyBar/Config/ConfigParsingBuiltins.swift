import Foundation
import TOMLKit

extension Config {

    func parseBuiltins(from toml: TOMLTable) throws {
        guard let builtins = toml["builtins"]?.table else { return }

        if let battery = builtins["battery"]?.table {
            let style = try parseBuiltinStyle(from: battery, path: "builtins.battery", fallback: builtinBattery.style)

            builtinBattery = BatteryBuiltinConfig(
                style: style,
                chargingIcon: try optionalString(battery["charging_icon"], path: "builtins.battery.charging_icon") ?? builtinBattery.chargingIcon,
                unavailableText: try optionalString(battery["unavailable_text"], path: "builtins.battery.unavailable_text") ?? builtinBattery.unavailableText,
                showPercentage: try optionalBool(battery["show_percentage"], path: "builtins.battery.show_percentage") ?? builtinBattery.showPercentage
            )
        }

        if let volume = builtins["volume"]?.table {
            let style = try parseBuiltinStyle(from: volume, path: "builtins.volume", fallback: builtinVolume.style)

            builtinVolume = VolumeBuiltinConfig(
                style: style,
                mutedIcon: try optionalString(volume["muted_icon"], path: "builtins.volume.muted_icon") ?? builtinVolume.mutedIcon,
                lowIcon: try optionalString(volume["low_icon"], path: "builtins.volume.low_icon") ?? builtinVolume.lowIcon,
                highIcon: try optionalString(volume["high_icon"], path: "builtins.volume.high_icon") ?? builtinVolume.highIcon,
                showPercentage: try optionalBool(volume["show_percentage"], path: "builtins.volume.show_percentage") ?? builtinVolume.showPercentage,
                minValue: try optionalNumber(volume["min"], path: "builtins.volume.min") ?? builtinVolume.minValue,
                maxValue: try optionalNumber(volume["max"], path: "builtins.volume.max") ?? builtinVolume.maxValue,
                step: try optionalNumber(volume["step"], path: "builtins.volume.step") ?? builtinVolume.step,
                expandToSliderOnHover: try optionalBool(volume["expand_to_slider_on_hover"], path: "builtins.volume.expand_to_slider_on_hover") ?? builtinVolume.expandToSliderOnHover,
                sliderWidth: try optionalNumber(volume["slider_width"], path: "builtins.volume.slider_width") ?? builtinVolume.sliderWidth
            )
        }

        if let date = builtins["date"]?.table {
            let style = try parseBuiltinStyle(from: date, path: "builtins.date", fallback: builtinDate.style)

            builtinDate = DateBuiltinConfig(
                style: style,
                format: try optionalString(date["format"], path: "builtins.date.format") ?? builtinDate.format
            )
        }

        if let time = builtins["time"]?.table {
            let style = try parseBuiltinStyle(from: time, path: "builtins.time", fallback: builtinTime.style)

            builtinTime = TimeBuiltinConfig(
                style: style,
                format: try optionalString(time["format"], path: "builtins.time.format") ?? builtinTime.format
            )
        }

        if let calendar = builtins["calendar"]?.table {
            let style = try parseBuiltinStyle(from: calendar, path: "builtins.calendar", fallback: builtinCalendar.style)

            builtinCalendar = CalendarBuiltinConfig(
                style: style,
                format: try optionalString(calendar["format"], path: "builtins.calendar.format") ?? builtinCalendar.format,
                days: max(1, try optionalInt(calendar["days"], path: "builtins.calendar.days") ?? builtinCalendar.days),
                emptyText: try optionalString(calendar["empty_text"], path: "builtins.calendar.empty_text") ?? builtinCalendar.emptyText,
                layout: normalizedCalendarLayout(try optionalString(calendar["layout"], path: "builtins.calendar.layout") ?? builtinCalendar.layout),
                topFormat: try optionalString(calendar["top_format"], path: "builtins.calendar.top_format") ?? builtinCalendar.topFormat,
                bottomFormat: try optionalString(calendar["bottom_format"], path: "builtins.calendar.bottom_format") ?? builtinCalendar.bottomFormat,
                lineSpacing: try optionalNumber(calendar["line_spacing"], path: "builtins.calendar.line_spacing") ?? builtinCalendar.lineSpacing,
                topTextColorHex: try optionalString(calendar["top_text_color"], path: "builtins.calendar.top_text_color") ?? builtinCalendar.topTextColorHex,
                bottomTextColorHex: try optionalString(calendar["bottom_text_color"], path: "builtins.calendar.bottom_text_color") ?? builtinCalendar.bottomTextColorHex,
                showBirthdays: try optionalBool(calendar["show_birthdays"], path: "builtins.calendar.show_birthdays") ?? builtinCalendar.showBirthdays,
                birthdaysTitle: try optionalString(calendar["birthdays_title"], path: "builtins.calendar.birthdays_title") ?? builtinCalendar.birthdaysTitle,
                birthdaysDateFormat: try optionalString(calendar["birthdays_date_format"], path: "builtins.calendar.birthdays_date_format") ?? builtinCalendar.birthdaysDateFormat,
                birthdaysShowAge: try optionalBool(calendar["birthdays_show_age"], path: "builtins.calendar.birthdays_show_age") ?? builtinCalendar.birthdaysShowAge,
                popupBackgroundColorHex: try optionalString(calendar["popup_background_color"], path: "builtins.calendar.popup_background_color") ?? builtinCalendar.popupBackgroundColorHex,
                popupBorderColorHex: try optionalString(calendar["popup_border_color"], path: "builtins.calendar.popup_border_color") ?? builtinCalendar.popupBorderColorHex,
                popupBorderWidth: try optionalNumber(calendar["popup_border_width"], path: "builtins.calendar.popup_border_width") ?? builtinCalendar.popupBorderWidth,
                popupCornerRadius: try optionalNumber(calendar["popup_corner_radius"], path: "builtins.calendar.popup_corner_radius") ?? builtinCalendar.popupCornerRadius,
                popupPaddingX: try optionalNumber(calendar["popup_padding_x"], path: "builtins.calendar.popup_padding_x") ?? builtinCalendar.popupPaddingX,
                popupPaddingY: try optionalNumber(calendar["popup_padding_y"], path: "builtins.calendar.popup_padding_y") ?? builtinCalendar.popupPaddingY,
                popupSpacing: try optionalNumber(calendar["popup_spacing"], path: "builtins.calendar.popup_spacing") ?? builtinCalendar.popupSpacing,
                popupItemIndent: try optionalNumber(calendar["popup_item_indent"], path: "builtins.calendar.popup_item_indent") ?? builtinCalendar.popupItemIndent,
                popupSectionTitleColorHex: try optionalString(calendar["popup_section_title_color"], path: "builtins.calendar.popup_section_title_color") ?? builtinCalendar.popupSectionTitleColorHex,
                popupItemColorHex: try optionalString(calendar["popup_item_color"], path: "builtins.calendar.popup_item_color") ?? builtinCalendar.popupItemColorHex,
                popupEmptyColorHex: try optionalString(calendar["popup_empty_color"], path: "builtins.calendar.popup_empty_color") ?? builtinCalendar.popupEmptyColorHex
            )
        }
    }

    func parseBuiltinStyle(
        from table: TOMLTable,
        path: String,
        fallback: BuiltinWidgetStyle
    ) throws -> BuiltinWidgetStyle {
        BuiltinWidgetStyle(
            enabled: try optionalBool(table["enabled"], path: "\(path).enabled") ?? fallback.enabled,
            position: normalizedPosition(try optionalString(table["position"], path: "\(path).position") ?? fallback.position),
            order: try optionalInt(table["order"], path: "\(path).order") ?? fallback.order,
            icon: try optionalString(table["icon"], path: "\(path).icon") ?? fallback.icon,
            textColorHex: try optionalString(table["text_color"], path: "\(path).text_color") ?? fallback.textColorHex,
            backgroundColorHex: try optionalString(table["background_color"], path: "\(path).background_color") ?? fallback.backgroundColorHex,
            borderColorHex: try optionalString(table["border_color"], path: "\(path).border_color") ?? fallback.borderColorHex,
            borderWidth: try optionalNumber(table["border_width"], path: "\(path).border_width") ?? fallback.borderWidth,
            cornerRadius: try optionalNumber(table["corner_radius"], path: "\(path).corner_radius") ?? fallback.cornerRadius,
            paddingX: try optionalNumber(table["padding_x"], path: "\(path).padding_x") ?? fallback.paddingX,
            paddingY: try optionalNumber(table["padding_y"], path: "\(path).padding_y") ?? fallback.paddingY,
            spacing: try optionalNumber(table["spacing"], path: "\(path).spacing") ?? fallback.spacing,
            opacity: try optionalNumber(table["opacity"], path: "\(path).opacity") ?? fallback.opacity
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

    private func optionalString(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
        guard let value else { return nil }
        return try requiredString(value, path: path)
    }

    private func optionalBool(_ value: (any TOMLValueConvertible)?, path: String) throws -> Bool? {
        guard let value else { return nil }
        return try requiredBool(value, path: path)
    }

    private func optionalInt(_ value: (any TOMLValueConvertible)?, path: String) throws -> Int? {
        guard let value else { return nil }
        return try requiredInt(value, path: path)
    }

    private func optionalNumber(_ value: (any TOMLValueConvertible)?, path: String) throws -> Double? {
        guard let value else { return nil }
        return try requiredNumber(value, path: path)
    }
}
