import Foundation
import TOMLKit

extension Config {

    func parseBuiltins(from toml: TOMLTable) throws {
        guard let builtins = toml["builtins"]?.table else { return }

        if let battery = builtins["battery"]?.table {
            let styleTable = battery["style"]?.table ?? battery
            let contentTable = battery["content"]?.table ?? battery

            builtinBattery = BatteryBuiltinConfig(
                style: try parseBuiltinStyle(
                    from: styleTable,
                    path: "builtins.battery.style",
                    fallback: builtinBattery.style
                ),
                content: .init(
                    unavailableText: try optionalString(
                        contentTable["unavailable_text"],
                        path: "builtins.battery.content.unavailable_text"
                    ) ?? builtinBattery.unavailableText,
                    showPercentage: try optionalBool(
                        contentTable["show_percentage"],
                        path: "builtins.battery.content.show_percentage"
                    ) ?? builtinBattery.showPercentage
                )
            )
        }

        if let spaces = builtins["spaces"]?.table {
            let styleTable = spaces["style"]?.table ?? spaces
            let layoutTable = spaces["layout"]?.table
            let textTable = spaces["text"]?.table
            let iconsTable = spaces["icons"]?.table
            let colorsTable = spaces["colors"]?.table

            builtinSpaces.style = try parseBuiltinStyle(
                from: styleTable,
                path: "builtins.spaces.style",
                fallback: builtinSpaces.style
            )

            if let layoutTable {
                builtinSpaces.layout = .init(
                    spacing: try optionalNumber(layoutTable["spacing"], path: "builtins.spaces.layout.spacing") ?? builtinSpaces.layout.spacing,
                    hideEmpty: try optionalBool(layoutTable["hide_empty"], path: "builtins.spaces.layout.hide_empty") ?? builtinSpaces.layout.hideEmpty,
                    paddingX: try optionalNumber(layoutTable["padding_x"], path: "builtins.spaces.layout.padding_x") ?? builtinSpaces.layout.paddingX,
                    paddingY: try optionalNumber(layoutTable["padding_y"], path: "builtins.spaces.layout.padding_y") ?? builtinSpaces.layout.paddingY,
                    cornerRadius: try optionalNumber(layoutTable["corner_radius"], path: "builtins.spaces.layout.corner_radius") ?? builtinSpaces.layout.cornerRadius,
                    focusedScale: try optionalNumber(layoutTable["focused_scale"], path: "builtins.spaces.layout.focused_scale") ?? builtinSpaces.layout.focusedScale,
                    inactiveOpacity: try optionalNumber(layoutTable["inactive_opacity"], path: "builtins.spaces.layout.inactive_opacity") ?? builtinSpaces.layout.inactiveOpacity,
                    maxIcons: try optionalInt(layoutTable["max_icons"], path: "builtins.spaces.layout.max_icons") ?? builtinSpaces.layout.maxIcons,
                    showNumber: try optionalBool(layoutTable["show_number"], path: "builtins.spaces.layout.show_number") ?? builtinSpaces.layout.showNumber,
                    showIcons: try optionalBool(layoutTable["show_icons"], path: "builtins.spaces.layout.show_icons") ?? builtinSpaces.layout.showIcons,
                    showOnlyFocusedLabel: try optionalBool(layoutTable["show_only_focused_label"], path: "builtins.spaces.layout.show_only_focused_label") ?? builtinSpaces.layout.showOnlyFocusedLabel,
                    collapseInactive: try optionalBool(layoutTable["collapse_inactive"], path: "builtins.spaces.layout.collapse_inactive") ?? builtinSpaces.layout.collapseInactive,
                    collapsedPaddingX: try optionalNumber(layoutTable["collapsed_padding_x"], path: "builtins.spaces.layout.collapsed_padding_x") ?? builtinSpaces.layout.collapsedPaddingX,
                    collapsedPaddingY: try optionalNumber(layoutTable["collapsed_padding_y"], path: "builtins.spaces.layout.collapsed_padding_y") ?? builtinSpaces.layout.collapsedPaddingY
                )
            }

            if let textTable {
                builtinSpaces.text = .init(
                    size: try optionalNumber(textTable["size"], path: "builtins.spaces.text.size") ?? builtinSpaces.text.size,
                    weight: try optionalString(textTable["weight"], path: "builtins.spaces.text.weight") ?? builtinSpaces.text.weight,
                    focusedColorHex: try optionalString(textTable["focused_color"], path: "builtins.spaces.text.focused_color") ?? builtinSpaces.text.focusedColorHex,
                    inactiveColorHex: try optionalString(textTable["inactive_color"], path: "builtins.spaces.text.inactive_color") ?? builtinSpaces.text.inactiveColorHex
                )
            }

            if let iconsTable {
                builtinSpaces.icons = .init(
                    size: try optionalNumber(iconsTable["size"], path: "builtins.spaces.icons.size") ?? builtinSpaces.icons.size,
                    spacing: try optionalNumber(iconsTable["spacing"], path: "builtins.spaces.icons.spacing") ?? builtinSpaces.icons.spacing,
                    cornerRadius: try optionalNumber(iconsTable["corner_radius"], path: "builtins.spaces.icons.corner_radius") ?? builtinSpaces.icons.cornerRadius,
                    focusedSize: try optionalNumber(iconsTable["focused_size"], path: "builtins.spaces.icons.focused_size") ?? builtinSpaces.icons.focusedSize,
                    borderWidth: try optionalNumber(iconsTable["border_width"], path: "builtins.spaces.icons.border_width") ?? builtinSpaces.icons.borderWidth,
                    focusedBorderWidth: try optionalNumber(iconsTable["focused_border_width"], path: "builtins.spaces.icons.focused_border_width") ?? builtinSpaces.icons.focusedBorderWidth
                )
            }

            if let colorsTable {
                builtinSpaces.colors = .init(
                    activeBackgroundHex: try optionalString(colorsTable["active_background"], path: "builtins.spaces.colors.active_background") ?? builtinSpaces.colors.activeBackgroundHex,
                    inactiveBackgroundHex: try optionalString(colorsTable["inactive_background"], path: "builtins.spaces.colors.inactive_background") ?? builtinSpaces.colors.inactiveBackgroundHex,
                    activeBorderHex: try optionalString(colorsTable["active_border"], path: "builtins.spaces.colors.active_border") ?? builtinSpaces.colors.activeBorderHex,
                    inactiveBorderHex: try optionalString(colorsTable["inactive_border"], path: "builtins.spaces.colors.inactive_border") ?? builtinSpaces.colors.inactiveBorderHex
                )
            }
        }

        if let frontApp = builtins["front_app"]?.table {
            let styleTable = frontApp["style"]?.table ?? frontApp
            let contentTable = frontApp["content"]?.table ?? frontApp

            builtinFrontApp = FrontAppBuiltinConfig(
                style: try parseBuiltinStyle(
                    from: styleTable,
                    path: "builtins.front_app.style",
                    fallback: builtinFrontApp.style
                ),
                content: .init(
                    showIcon: try optionalBool(contentTable["show_icon"], path: "builtins.front_app.content.show_icon") ?? builtinFrontApp.showIcon,
                    showName: try optionalBool(contentTable["show_name"], path: "builtins.front_app.content.show_name") ?? builtinFrontApp.showName,
                    fallbackText: try optionalString(contentTable["fallback_text"], path: "builtins.front_app.content.fallback_text") ?? builtinFrontApp.fallbackText,
                    iconSize: try optionalNumber(contentTable["icon_size"], path: "builtins.front_app.content.icon_size") ?? builtinFrontApp.iconSize,
                    iconCornerRadius: try optionalNumber(contentTable["icon_corner_radius"], path: "builtins.front_app.content.icon_corner_radius") ?? builtinFrontApp.iconCornerRadius
                )
            )
        }

        if let volume = builtins["volume"]?.table {
            let styleTable = volume["style"]?.table ?? volume
            let contentTable = volume["content"]?.table ?? volume
            let sliderTable = volume["slider"]?.table ?? volume

            let sliderWidth = try (
                optionalNumber(sliderTable["width"], path: "builtins.volume.slider.width")
                ?? optionalNumber(sliderTable["slider_width"], path: "builtins.volume.slider.slider_width")
                ?? builtinVolume.sliderWidth
            )

            builtinVolume = VolumeBuiltinConfig(
                style: try parseBuiltinStyle(
                    from: styleTable,
                    path: "builtins.volume.style",
                    fallback: builtinVolume.style
                ),
                content: .init(
                    mutedIcon: try optionalString(contentTable["muted_icon"], path: "builtins.volume.content.muted_icon") ?? builtinVolume.mutedIcon,
                    lowIcon: try optionalString(contentTable["low_icon"], path: "builtins.volume.content.low_icon") ?? builtinVolume.lowIcon,
                    highIcon: try optionalString(contentTable["high_icon"], path: "builtins.volume.content.high_icon") ?? builtinVolume.highIcon,
                    showPercentage: try optionalBool(contentTable["show_percentage"], path: "builtins.volume.content.show_percentage") ?? builtinVolume.showPercentage,
                    minValue: try optionalNumber(contentTable["min"], path: "builtins.volume.content.min") ?? builtinVolume.minValue,
                    maxValue: try optionalNumber(contentTable["max"], path: "builtins.volume.content.max") ?? builtinVolume.maxValue,
                    step: try optionalNumber(contentTable["step"], path: "builtins.volume.content.step") ?? builtinVolume.step
                ),
                slider: .init(
                    expandToSliderOnHover: try optionalBool(
                        sliderTable["expand_to_slider_on_hover"],
                        path: "builtins.volume.slider.expand_to_slider_on_hover"
                    ) ?? builtinVolume.expandToSliderOnHover,
                    width: sliderWidth
                )
            )
        }

        if let date = builtins["date"]?.table {
            let styleTable = date["style"]?.table ?? date
            let contentTable = date["content"]?.table ?? date

            builtinDate = DateBuiltinConfig(
                style: try parseBuiltinStyle(
                    from: styleTable,
                    path: "builtins.date.style",
                    fallback: builtinDate.style
                ),
                content: .init(
                    format: try optionalString(contentTable["format"], path: "builtins.date.content.format") ?? builtinDate.format
                )
            )
        }

        if let time = builtins["time"]?.table {
            let styleTable = time["style"]?.table ?? time
            let contentTable = time["content"]?.table ?? time

            builtinTime = TimeBuiltinConfig(
                style: try parseBuiltinStyle(
                    from: styleTable,
                    path: "builtins.time.style",
                    fallback: builtinTime.style
                ),
                content: .init(
                    format: try optionalString(contentTable["format"], path: "builtins.time.content.format") ?? builtinTime.format
                )
            )
        }

        if let calendar = builtins["calendar"]?.table {
            let styleTable = calendar["style"]?.table ?? calendar
            let anchorTable = calendar["anchor"]?.table ?? calendar
            let eventsTable = calendar["events"]?.table ?? calendar
            let birthdaysTable = calendar["birthdays"]?.table ?? calendar
            let popupTable = calendar["popup"]?.table ?? calendar

            let birthdaysShow = try (
                optionalBool(birthdaysTable["show"], path: "builtins.calendar.birthdays.show")
                ?? optionalBool(birthdaysTable["show_birthdays"], path: "builtins.calendar.birthdays.show_birthdays")
                ?? builtinCalendar.showBirthdays
            )

            let birthdaysTitle = try (
                optionalString(birthdaysTable["title"], path: "builtins.calendar.birthdays.title")
                ?? optionalString(birthdaysTable["birthdays_title"], path: "builtins.calendar.birthdays.birthdays_title")
                ?? builtinCalendar.birthdaysTitle
            )

            let birthdaysDateFormat = try (
                optionalString(birthdaysTable["date_format"], path: "builtins.calendar.birthdays.date_format")
                ?? optionalString(birthdaysTable["birthdays_date_format"], path: "builtins.calendar.birthdays.birthdays_date_format")
                ?? builtinCalendar.birthdaysDateFormat
            )

            let birthdaysShowAge = try (
                optionalBool(birthdaysTable["show_age"], path: "builtins.calendar.birthdays.show_age")
                ?? optionalBool(birthdaysTable["birthdays_show_age"], path: "builtins.calendar.birthdays.birthdays_show_age")
                ?? builtinCalendar.birthdaysShowAge
            )

            let popupBackgroundColor = try (
                optionalString(popupTable["background_color"], path: "builtins.calendar.popup.background_color")
                ?? optionalString(popupTable["popup_background_color"], path: "builtins.calendar.popup.popup_background_color")
                ?? builtinCalendar.popupBackgroundColorHex
            )

            let popupBorderColor = try (
                optionalString(popupTable["border_color"], path: "builtins.calendar.popup.border_color")
                ?? optionalString(popupTable["popup_border_color"], path: "builtins.calendar.popup.popup_border_color")
                ?? builtinCalendar.popupBorderColorHex
            )

            let popupBorderWidth = try (
                optionalNumber(popupTable["border_width"], path: "builtins.calendar.popup.border_width")
                ?? optionalNumber(popupTable["popup_border_width"], path: "builtins.calendar.popup.popup_border_width")
                ?? builtinCalendar.popupBorderWidth
            )

            let popupCornerRadius = try (
                optionalNumber(popupTable["corner_radius"], path: "builtins.calendar.popup.corner_radius")
                ?? optionalNumber(popupTable["popup_corner_radius"], path: "builtins.calendar.popup.popup_corner_radius")
                ?? builtinCalendar.popupCornerRadius
            )

            let popupPaddingX = try (
                optionalNumber(popupTable["padding_x"], path: "builtins.calendar.popup.padding_x")
                ?? optionalNumber(popupTable["popup_padding_x"], path: "builtins.calendar.popup.popup_padding_x")
                ?? builtinCalendar.popupPaddingX
            )

            let popupPaddingY = try (
                optionalNumber(popupTable["padding_y"], path: "builtins.calendar.popup.padding_y")
                ?? optionalNumber(popupTable["popup_padding_y"], path: "builtins.calendar.popup.popup_padding_y")
                ?? builtinCalendar.popupPaddingY
            )

            let popupSpacing = try (
                optionalNumber(popupTable["spacing"], path: "builtins.calendar.popup.spacing")
                ?? optionalNumber(popupTable["popup_spacing"], path: "builtins.calendar.popup.popup_spacing")
                ?? builtinCalendar.popupSpacing
            )

            let popupItemIndent = try (
                optionalNumber(popupTable["item_indent"], path: "builtins.calendar.popup.item_indent")
                ?? optionalNumber(popupTable["popup_item_indent"], path: "builtins.calendar.popup.popup_item_indent")
                ?? builtinCalendar.popupItemIndent
            )

            let popupSectionTitleColor = try (
                optionalString(popupTable["section_title_color"], path: "builtins.calendar.popup.section_title_color")
                ?? optionalString(popupTable["popup_section_title_color"], path: "builtins.calendar.popup.popup_section_title_color")
                ?? builtinCalendar.popupSectionTitleColorHex
            )

            let popupItemColor = try (
                optionalString(popupTable["item_color"], path: "builtins.calendar.popup.item_color")
                ?? optionalString(popupTable["popup_item_color"], path: "builtins.calendar.popup.popup_item_color")
                ?? builtinCalendar.popupItemColorHex
            )

            let popupEmptyColor = try (
                optionalString(popupTable["empty_color"], path: "builtins.calendar.popup.empty_color")
                ?? optionalString(popupTable["popup_empty_color"], path: "builtins.calendar.popup.popup_empty_color")
                ?? builtinCalendar.popupEmptyColorHex
            )

            builtinCalendar = CalendarBuiltinConfig(
                style: try parseBuiltinStyle(
                    from: styleTable,
                    path: "builtins.calendar.style",
                    fallback: builtinCalendar.style
                ),
                anchor: .init(
                    format: try optionalString(anchorTable["format"], path: "builtins.calendar.anchor.format") ?? builtinCalendar.format,
                    layout: normalizedCalendarLayout(
                        try optionalString(anchorTable["layout"], path: "builtins.calendar.anchor.layout") ?? builtinCalendar.layout
                    ),
                    topFormat: try optionalString(anchorTable["top_format"], path: "builtins.calendar.anchor.top_format") ?? builtinCalendar.topFormat,
                    bottomFormat: try optionalString(anchorTable["bottom_format"], path: "builtins.calendar.anchor.bottom_format") ?? builtinCalendar.bottomFormat,
                    lineSpacing: try optionalNumber(anchorTable["line_spacing"], path: "builtins.calendar.anchor.line_spacing") ?? builtinCalendar.lineSpacing,
                    topTextColorHex: try optionalString(anchorTable["top_text_color"], path: "builtins.calendar.anchor.top_text_color") ?? builtinCalendar.topTextColorHex,
                    bottomTextColorHex: try optionalString(anchorTable["bottom_text_color"], path: "builtins.calendar.anchor.bottom_text_color") ?? builtinCalendar.bottomTextColorHex
                ),
                events: .init(
                    days: max(1, try optionalInt(eventsTable["days"], path: "builtins.calendar.events.days") ?? builtinCalendar.days),
                    emptyText: try optionalString(eventsTable["empty_text"], path: "builtins.calendar.events.empty_text") ?? builtinCalendar.emptyText
                ),
                birthdays: .init(
                    show: birthdaysShow,
                    title: birthdaysTitle,
                    dateFormat: birthdaysDateFormat,
                    showAge: birthdaysShowAge
                ),
                popup: .init(
                    backgroundColorHex: popupBackgroundColor,
                    borderColorHex: popupBorderColor,
                    borderWidth: popupBorderWidth,
                    cornerRadius: popupCornerRadius,
                    paddingX: popupPaddingX,
                    paddingY: popupPaddingY,
                    spacing: popupSpacing,
                    itemIndent: popupItemIndent,
                    sectionTitleColorHex: popupSectionTitleColor,
                    itemColorHex: popupItemColor,
                    emptyColorHex: popupEmptyColor
                )
            )
        }
    }
}
