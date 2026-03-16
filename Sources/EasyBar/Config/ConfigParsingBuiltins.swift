import Foundation
import TOMLKit

extension Config {

    func parseBuiltins(from toml: TOMLTable) throws {
        guard let builtins = toml["builtins"]?.table else { return }

        try parseCPUBuiltin(from: builtins)
        try parseBatteryBuiltin(from: builtins)
        try parseSpacesBuiltin(from: builtins)
        try parseFrontAppBuiltin(from: builtins)
        try parseVolumeBuiltin(from: builtins)
        try parseDateBuiltin(from: builtins)
        try parseTimeBuiltin(from: builtins)
        try parseCalendarBuiltin(from: builtins)
    }

    private func parseCPUBuiltin(from builtins: TOMLTable) throws {
        guard let cpu = builtins["cpu"]?.table else { return }

        let styleTable = cpu["style"]?.table ?? TOMLTable()
        let contentTable = cpu["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.cpu.style",
            fallback: builtinCPU.style
        )

        let content = Config.CPUBuiltinConfig.Content(
            label: try optionalString(
                contentTable["label"],
                path: "builtins.cpu.content.label"
            ) ?? builtinCPU.label,
            historySize: max(
                2,
                try optionalInt(
                    contentTable["history_size"],
                    path: "builtins.cpu.content.history_size"
                ) ?? builtinCPU.historySize
            ),
            lineWidth: try optionalNumber(
                contentTable["line_width"],
                path: "builtins.cpu.content.line_width"
            ) ?? builtinCPU.lineWidth,
            colorHex: try optionalString(
                contentTable["color"],
                path: "builtins.cpu.content.color"
            ) ?? builtinCPU.colorHex
        )

        builtinCPU = CPUBuiltinConfig(
            style: style,
            content: content
        )
    }

    private func parseBatteryBuiltin(from builtins: TOMLTable) throws {
        guard let battery = builtins["battery"]?.table else { return }

        let styleTable = battery["style"]?.table ?? TOMLTable()
        let contentTable = battery["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.battery.style",
            fallback: builtinBattery.style
        )

        let unavailableText = try optionalString(
            contentTable["unavailable_text"],
            path: "builtins.battery.content.unavailable_text"
        ) ?? builtinBattery.unavailableText

        let showPercentage = try optionalBool(
            contentTable["show_percentage"],
            path: "builtins.battery.content.show_percentage"
        ) ?? builtinBattery.showPercentage

        builtinBattery = BatteryBuiltinConfig(
            style: style,
            content: .init(
                unavailableText: unavailableText,
                showPercentage: showPercentage
            )
        )
    }

    private func parseSpacesBuiltin(from builtins: TOMLTable) throws {
        guard let spaces = builtins["spaces"]?.table else { return }

        let styleTable = spaces["style"]?.table ?? TOMLTable()
        let layoutTable = spaces["layout"]?.table ?? TOMLTable()
        let textTable = spaces["text"]?.table ?? TOMLTable()
        let iconsTable = spaces["icons"]?.table ?? TOMLTable()
        let colorsTable = spaces["colors"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.spaces.style",
            fallback: builtinSpaces.style
        )

        let layout = Config.SpacesBuiltinConfig.Layout(
            spacing: try optionalNumber(
                layoutTable["spacing"],
                path: "builtins.spaces.layout.spacing"
            ) ?? builtinSpaces.layout.spacing,
            hideEmpty: try optionalBool(
                layoutTable["hide_empty"],
                path: "builtins.spaces.layout.hide_empty"
            ) ?? builtinSpaces.layout.hideEmpty,
            paddingX: try optionalNumber(
                layoutTable["padding_x"],
                path: "builtins.spaces.layout.padding_x"
            ) ?? builtinSpaces.layout.paddingX,
            paddingY: try optionalNumber(
                layoutTable["padding_y"],
                path: "builtins.spaces.layout.padding_y"
            ) ?? builtinSpaces.layout.paddingY,
            cornerRadius: try optionalNumber(
                layoutTable["corner_radius"],
                path: "builtins.spaces.layout.corner_radius"
            ) ?? builtinSpaces.layout.cornerRadius,
            focusedScale: try optionalNumber(
                layoutTable["focused_scale"],
                path: "builtins.spaces.layout.focused_scale"
            ) ?? builtinSpaces.layout.focusedScale,
            inactiveOpacity: try optionalNumber(
                layoutTable["inactive_opacity"],
                path: "builtins.spaces.layout.inactive_opacity"
            ) ?? builtinSpaces.layout.inactiveOpacity,
            maxIcons: try optionalInt(
                layoutTable["max_icons"],
                path: "builtins.spaces.layout.max_icons"
            ) ?? builtinSpaces.layout.maxIcons,
            showNumber: try optionalBool(
                layoutTable["show_number"],
                path: "builtins.spaces.layout.show_number"
            ) ?? builtinSpaces.layout.showNumber,
            showIcons: try optionalBool(
                layoutTable["show_icons"],
                path: "builtins.spaces.layout.show_icons"
            ) ?? builtinSpaces.layout.showIcons,
            showOnlyFocusedLabel: try optionalBool(
                layoutTable["show_only_focused_label"],
                path: "builtins.spaces.layout.show_only_focused_label"
            ) ?? builtinSpaces.layout.showOnlyFocusedLabel,
            collapseInactive: try optionalBool(
                layoutTable["collapse_inactive"],
                path: "builtins.spaces.layout.collapse_inactive"
            ) ?? builtinSpaces.layout.collapseInactive,
            collapsedPaddingX: try optionalNumber(
                layoutTable["collapsed_padding_x"],
                path: "builtins.spaces.layout.collapsed_padding_x"
            ) ?? builtinSpaces.layout.collapsedPaddingX,
            collapsedPaddingY: try optionalNumber(
                layoutTable["collapsed_padding_y"],
                path: "builtins.spaces.layout.collapsed_padding_y"
            ) ?? builtinSpaces.layout.collapsedPaddingY
        )

        let text = Config.SpacesBuiltinConfig.Text(
            size: try optionalNumber(
                textTable["size"],
                path: "builtins.spaces.text.size"
            ) ?? builtinSpaces.text.size,
            weight: try optionalString(
                textTable["weight"],
                path: "builtins.spaces.text.weight"
            ) ?? builtinSpaces.text.weight,
            focusedColorHex: try optionalString(
                textTable["focused_color"],
                path: "builtins.spaces.text.focused_color"
            ) ?? builtinSpaces.text.focusedColorHex,
            inactiveColorHex: try optionalString(
                textTable["inactive_color"],
                path: "builtins.spaces.text.inactive_color"
            ) ?? builtinSpaces.text.inactiveColorHex
        )

        let icons = Config.SpacesBuiltinConfig.Icons(
            size: try optionalNumber(
                iconsTable["size"],
                path: "builtins.spaces.icons.size"
            ) ?? builtinSpaces.icons.size,
            spacing: try optionalNumber(
                iconsTable["spacing"],
                path: "builtins.spaces.icons.spacing"
            ) ?? builtinSpaces.icons.spacing,
            cornerRadius: try optionalNumber(
                iconsTable["corner_radius"],
                path: "builtins.spaces.icons.corner_radius"
            ) ?? builtinSpaces.icons.cornerRadius,
            focusedSize: try optionalNumber(
                iconsTable["focused_size"],
                path: "builtins.spaces.icons.focused_size"
            ) ?? builtinSpaces.icons.focusedSize,
            borderWidth: try optionalNumber(
                iconsTable["border_width"],
                path: "builtins.spaces.icons.border_width"
            ) ?? builtinSpaces.icons.borderWidth,
            focusedBorderWidth: try optionalNumber(
                iconsTable["focused_border_width"],
                path: "builtins.spaces.icons.focused_border_width"
            ) ?? builtinSpaces.icons.focusedBorderWidth
        )

        let colors = Config.SpacesBuiltinConfig.Colors(
            activeBackgroundHex: try optionalString(
                colorsTable["active_background"],
                path: "builtins.spaces.colors.active_background"
            ) ?? builtinSpaces.colors.activeBackgroundHex,
            inactiveBackgroundHex: try optionalString(
                colorsTable["inactive_background"],
                path: "builtins.spaces.colors.inactive_background"
            ) ?? builtinSpaces.colors.inactiveBackgroundHex,
            activeBorderHex: try optionalString(
                colorsTable["active_border"],
                path: "builtins.spaces.colors.active_border"
            ) ?? builtinSpaces.colors.activeBorderHex,
            inactiveBorderHex: try optionalString(
                colorsTable["inactive_border"],
                path: "builtins.spaces.colors.inactive_border"
            ) ?? builtinSpaces.colors.inactiveBorderHex
        )

        builtinSpaces = SpacesBuiltinConfig(
            style: style,
            layout: layout,
            text: text,
            icons: icons,
            colors: colors
        )
    }

    private func parseFrontAppBuiltin(from builtins: TOMLTable) throws {
        guard let frontApp = builtins["front_app"]?.table else { return }

        let styleTable = frontApp["style"]?.table ?? TOMLTable()
        let contentTable = frontApp["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.front_app.style",
            fallback: builtinFrontApp.style
        )

        let showIcon = try optionalBool(
            contentTable["show_icon"],
            path: "builtins.front_app.content.show_icon"
        ) ?? builtinFrontApp.showIcon

        let showName = try optionalBool(
            contentTable["show_name"],
            path: "builtins.front_app.content.show_name"
        ) ?? builtinFrontApp.showName

        let fallbackText = try optionalString(
            contentTable["fallback_text"],
            path: "builtins.front_app.content.fallback_text"
        ) ?? builtinFrontApp.fallbackText

        let iconSize = try optionalNumber(
            contentTable["icon_size"],
            path: "builtins.front_app.content.icon_size"
        ) ?? builtinFrontApp.iconSize

        let iconCornerRadius = try optionalNumber(
            contentTable["icon_corner_radius"],
            path: "builtins.front_app.content.icon_corner_radius"
        ) ?? builtinFrontApp.iconCornerRadius

        builtinFrontApp = FrontAppBuiltinConfig(
            style: style,
            content: .init(
                showIcon: showIcon,
                showName: showName,
                fallbackText: fallbackText,
                iconSize: iconSize,
                iconCornerRadius: iconCornerRadius
            )
        )
    }

    private func parseVolumeBuiltin(from builtins: TOMLTable) throws {
        guard let volume = builtins["volume"]?.table else { return }

        let styleTable = volume["style"]?.table ?? TOMLTable()
        let contentTable = volume["content"]?.table ?? TOMLTable()
        let sliderTable = volume["slider"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.volume.style",
            fallback: builtinVolume.style
        )

        let content = Config.VolumeBuiltinConfig.Content(
            mutedIcon: try optionalString(
                contentTable["muted_icon"],
                path: "builtins.volume.content.muted_icon"
            ) ?? builtinVolume.mutedIcon,
            lowIcon: try optionalString(
                contentTable["low_icon"],
                path: "builtins.volume.content.low_icon"
            ) ?? builtinVolume.lowIcon,
            highIcon: try optionalString(
                contentTable["high_icon"],
                path: "builtins.volume.content.high_icon"
            ) ?? builtinVolume.highIcon,
            showPercentage: try optionalBool(
                contentTable["show_percentage"],
                path: "builtins.volume.content.show_percentage"
            ) ?? builtinVolume.showPercentage,
            minValue: try optionalNumber(
                contentTable["min"],
                path: "builtins.volume.content.min"
            ) ?? builtinVolume.minValue,
            maxValue: try optionalNumber(
                contentTable["max"],
                path: "builtins.volume.content.max"
            ) ?? builtinVolume.maxValue,
            step: try optionalNumber(
                contentTable["step"],
                path: "builtins.volume.content.step"
            ) ?? builtinVolume.step
        )

        let slider = Config.VolumeBuiltinConfig.Slider(
            expandToSliderOnHover: try optionalBool(
                sliderTable["expand_to_slider_on_hover"],
                path: "builtins.volume.slider.expand_to_slider_on_hover"
            ) ?? builtinVolume.expandToSliderOnHover,
            width: try optionalNumber(
                sliderTable["width"],
                path: "builtins.volume.slider.width"
            ) ?? builtinVolume.sliderWidth
        )

        builtinVolume = VolumeBuiltinConfig(
            style: style,
            content: content,
            slider: slider
        )
    }

    private func parseDateBuiltin(from builtins: TOMLTable) throws {
        guard let date = builtins["date"]?.table else { return }

        let styleTable = date["style"]?.table ?? TOMLTable()
        let contentTable = date["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.date.style",
            fallback: builtinDate.style
        )

        let format = try optionalString(
            contentTable["format"],
            path: "builtins.date.content.format"
        ) ?? builtinDate.format

        builtinDate = DateBuiltinConfig(
            style: style,
            content: .init(format: format)
        )
    }

    private func parseTimeBuiltin(from builtins: TOMLTable) throws {
        guard let time = builtins["time"]?.table else { return }

        let styleTable = time["style"]?.table ?? TOMLTable()
        let contentTable = time["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.time.style",
            fallback: builtinTime.style
        )

        let format = try optionalString(
            contentTable["format"],
            path: "builtins.time.content.format"
        ) ?? builtinTime.format

        builtinTime = TimeBuiltinConfig(
            style: style,
            content: .init(format: format)
        )
    }

    private func parseCalendarBuiltin(from builtins: TOMLTable) throws {
        guard let calendar = builtins["calendar"]?.table else { return }

        let styleTable = calendar["style"]?.table ?? TOMLTable()
        let anchorTable = calendar["anchor"]?.table ?? TOMLTable()
        let eventsTable = calendar["events"]?.table ?? TOMLTable()
        let birthdaysTable = calendar["birthdays"]?.table ?? TOMLTable()
        let popupTable = calendar["popup"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.calendar.style",
            fallback: builtinCalendar.style
        )

        let anchor = Config.CalendarBuiltinConfig.Anchor(
            format: try optionalString(
                anchorTable["format"],
                path: "builtins.calendar.anchor.format"
            ) ?? builtinCalendar.format,
            layout: normalizedCalendarLayout(
                try optionalString(
                    anchorTable["layout"],
                    path: "builtins.calendar.anchor.layout"
                ) ?? builtinCalendar.layout
            ),
            topFormat: try optionalString(
                anchorTable["top_format"],
                path: "builtins.calendar.anchor.top_format"
            ) ?? builtinCalendar.topFormat,
            bottomFormat: try optionalString(
                anchorTable["bottom_format"],
                path: "builtins.calendar.anchor.bottom_format"
            ) ?? builtinCalendar.bottomFormat,
            lineSpacing: try optionalNumber(
                anchorTable["line_spacing"],
                path: "builtins.calendar.anchor.line_spacing"
            ) ?? builtinCalendar.lineSpacing,
            topTextColorHex: try optionalString(
                anchorTable["top_text_color"],
                path: "builtins.calendar.anchor.top_text_color"
            ) ?? builtinCalendar.topTextColorHex,
            bottomTextColorHex: try optionalString(
                anchorTable["bottom_text_color"],
                path: "builtins.calendar.anchor.bottom_text_color"
            ) ?? builtinCalendar.bottomTextColorHex
        )

        let events = Config.CalendarBuiltinConfig.Events(
            days: max(
                1,
                try optionalInt(
                    eventsTable["days"],
                    path: "builtins.calendar.events.days"
                ) ?? builtinCalendar.days
            ),
            emptyText: try optionalString(
                eventsTable["empty_text"],
                path: "builtins.calendar.events.empty_text"
            ) ?? builtinCalendar.emptyText
        )

        let birthdays = Config.CalendarBuiltinConfig.Birthdays(
            show: try optionalBool(
                birthdaysTable["show"],
                path: "builtins.calendar.birthdays.show"
            ) ?? builtinCalendar.showBirthdays,
            title: try optionalString(
                birthdaysTable["title"],
                path: "builtins.calendar.birthdays.title"
            ) ?? builtinCalendar.birthdaysTitle,
            dateFormat: try optionalString(
                birthdaysTable["date_format"],
                path: "builtins.calendar.birthdays.date_format"
            ) ?? builtinCalendar.birthdaysDateFormat,
            showAge: try optionalBool(
                birthdaysTable["show_age"],
                path: "builtins.calendar.birthdays.show_age"
            ) ?? builtinCalendar.birthdaysShowAge
        )

        let popup = Config.CalendarBuiltinConfig.Popup(
            backgroundColorHex: try optionalString(
                popupTable["background_color"],
                path: "builtins.calendar.popup.background_color"
            ) ?? builtinCalendar.popupBackgroundColorHex,
            borderColorHex: try optionalString(
                popupTable["border_color"],
                path: "builtins.calendar.popup.border_color"
            ) ?? builtinCalendar.popupBorderColorHex,
            borderWidth: try optionalNumber(
                popupTable["border_width"],
                path: "builtins.calendar.popup.border_width"
            ) ?? builtinCalendar.popupBorderWidth,
            cornerRadius: try optionalNumber(
                popupTable["corner_radius"],
                path: "builtins.calendar.popup.corner_radius"
            ) ?? builtinCalendar.popupCornerRadius,
            paddingX: try optionalNumber(
                popupTable["padding_x"],
                path: "builtins.calendar.popup.padding_x"
            ) ?? builtinCalendar.popupPaddingX,
            paddingY: try optionalNumber(
                popupTable["padding_y"],
                path: "builtins.calendar.popup.padding_y"
            ) ?? builtinCalendar.popupPaddingY,
            spacing: try optionalNumber(
                popupTable["spacing"],
                path: "builtins.calendar.popup.spacing"
            ) ?? builtinCalendar.popupSpacing,
            itemIndent: try optionalNumber(
                popupTable["item_indent"],
                path: "builtins.calendar.popup.item_indent"
            ) ?? builtinCalendar.popupItemIndent,
            sectionTitleColorHex: try optionalString(
                popupTable["section_title_color"],
                path: "builtins.calendar.popup.section_title_color"
            ) ?? builtinCalendar.popupSectionTitleColorHex,
            itemColorHex: try optionalString(
                popupTable["item_color"],
                path: "builtins.calendar.popup.item_color"
            ) ?? builtinCalendar.popupItemColorHex,
            emptyColorHex: try optionalString(
                popupTable["empty_color"],
                path: "builtins.calendar.popup.empty_color"
            ) ?? builtinCalendar.popupEmptyColorHex
        )

        builtinCalendar = CalendarBuiltinConfig(
            style: style,
            anchor: anchor,
            events: events,
            birthdays: birthdays,
            popup: popup
        )
    }
}
