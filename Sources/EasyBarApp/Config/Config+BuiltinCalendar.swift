import EasyBarCalendarConfig
import TOMLKit

extension Config {
  /// Parses the built-in calendar widget.
  func parseCalendarBuiltin(from builtins: TOMLTable) throws {
    guard let calendar = builtins["calendar"]?.table else { return }

    builtinCalendar = try parseCalendarBuiltinConfig(
      from: calendar,
      fallback: builtinCalendar,
      path: "builtins.calendar"
    ).resolvingThemeColorReferences { [self] value in
      resolveThemeColorHex(value) ?? value
    }
  }

  /// Parses the complete built-in calendar config from the app config table.
  func parseCalendarBuiltinConfig(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig,
    path: String
  ) throws -> CalendarBuiltinConfig {
    let styleTable = table["style"]?.table ?? TOMLTable()
    let anchorTable = table["anchor"]?.table ?? TOMLTable()
    let filtersTable = table["filters"]?.table ?? TOMLTable()
    let appointmentsTable = table["appointments"]?.table ?? TOMLTable()
    let birthdaysTable = table["birthdays"]?.table ?? TOMLTable()
    let composerTable = table["composer"]?.table ?? TOMLTable()

    let upcomingTable = table["upcoming"]?.table ?? TOMLTable()
    let upcomingEventsTable = upcomingTable["events"]?.table ?? TOMLTable()
    let upcomingPopupTable = upcomingTable["popup"]?.table ?? TOMLTable()

    let monthTable = table["month"]?.table ?? TOMLTable()
    let monthPopupTable = monthTable["popup"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig(
      placement: try parseCalendarPlacement(
        from: table,
        path: path,
        fallback: fallback.placement
      ),
      style: try parseCalendarWidgetStyle(
        from: styleTable,
        path: "\(path).style",
        fallback: fallback.style
      ),
      popupMode: try parseCalendarPopupMode(
        try optionalField(
          .string("popup_mode"),
          from: table,
          path: path,
          fallback: fallback.popupMode.rawValue
        ),
        path: "\(path).popup_mode"
      ),
      anchor: try parseCalendarAnchor(
        from: anchorTable,
        fallback: fallback.anchor
      ),
      filters: try parseCalendarFilters(
        from: filtersTable,
        fallback: fallback.filters
      ),
      appointments: try parseCalendarAppointments(
        from: appointmentsTable,
        fallback: fallback.appointments
      ),
      birthdays: try parseCalendarBirthdays(
        from: birthdaysTable,
        fallback: fallback.birthdays
      ),
      composer: try parseCalendarComposer(
        from: composerTable,
        fallback: fallback.composer
      ),
      upcoming: try parseCalendarUpcoming(
        eventsTable: upcomingEventsTable,
        popupTable: upcomingPopupTable,
        fallback: fallback.upcoming
      ),
      month: try parseCalendarMonth(
        popupTable: monthPopupTable,
        fallback: fallback.month
      )
    )
  }

  /// Parses shared calendar widget placement fields.
  func parseCalendarPlacement(
    from table: TOMLTable,
    path: String,
    fallback: CalendarWidgetPlacement
  ) throws -> CalendarWidgetPlacement {
    CalendarWidgetPlacement(
      enabled: try optionalField(
        .bool("enabled"),
        from: table,
        path: path,
        fallback: fallback.enabled
      ),
      position: try parsePosition(
        try optionalField(
          .string("position"),
          from: table,
          path: path,
          fallback: fallback.position.rawValue
        ),
        path: "\(path).position"
      ),
      order: try optionalField(
        .int("order"),
        from: table,
        path: path,
        fallback: fallback.order
      ),
      group: try optionalField(
        .string("group"),
        from: table,
        path: path,
        fallback: fallback.group
      )
    )
  }

  /// Parses shared calendar widget style fields.
  func parseCalendarWidgetStyle(
    from table: TOMLTable,
    path: String,
    fallback: CalendarWidgetStyle
  ) throws -> CalendarWidgetStyle {
    CalendarWidgetStyle(
      icon: try optionalField(
        .string("icon"),
        from: table,
        path: path,
        fallback: fallback.icon
      ),
      textColorHex: try optionalField(
        .string("text_color"),
        from: table,
        path: path,
        fallback: fallback.textColorHex
      ),
      backgroundColorHex: try optionalField(
        .string("background_color"),
        from: table,
        path: path,
        fallback: fallback.backgroundColorHex
      ),
      borderColorHex: try optionalField(
        .string("border_color"),
        from: table,
        path: path,
        fallback: fallback.borderColorHex
      ),
      borderWidth: try optionalField(
        .number("border_width"),
        from: table,
        path: path,
        fallback: fallback.borderWidth
      ),
      cornerRadius: try optionalField(
        .number("corner_radius"),
        from: table,
        path: path,
        fallback: fallback.cornerRadius
      ),
      marginX: try optionalField(
        .number("margin_x"),
        from: table,
        path: path,
        fallback: fallback.marginX
      ),
      marginY: try optionalField(
        .number("margin_y"),
        from: table,
        path: path,
        fallback: fallback.marginY
      ),
      paddingX: try optionalField(
        .number("padding_x"),
        from: table,
        path: path,
        fallback: fallback.paddingX
      ),
      paddingY: try optionalField(
        .number("padding_y"),
        from: table,
        path: path,
        fallback: fallback.paddingY
      ),
      spacing: try optionalField(
        .number("spacing"),
        from: table,
        path: path,
        fallback: fallback.spacing
      ),
      opacity: try optionalField(
        .number("opacity"),
        from: table,
        path: path,
        fallback: fallback.opacity
      )
    )
  }

  /// Parses calendar include/exclude filters.
  func parseCalendarFilters(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Filters
  ) throws -> CalendarBuiltinConfig.Filters {
    CalendarBuiltinConfig.Filters(
      includedCalendarNames: try optionalField(
        .stringArray("included_calendar_names"),
        from: table,
        path: "builtins.calendar.filters",
        fallback: fallback.includedCalendarNames
      ),
      excludedCalendarNames: try optionalField(
        .stringArray("excluded_calendar_names"),
        from: table,
        path: "builtins.calendar.filters",
        fallback: fallback.excludedCalendarNames
      ),
      includedCalendarIDs: try optionalField(
        .stringArray("included_calendar_ids"),
        from: table,
        path: "builtins.calendar.filters",
        fallback: fallback.includedCalendarIDs
      ),
      excludedCalendarIDs: try optionalField(
        .stringArray("excluded_calendar_ids"),
        from: table,
        path: "builtins.calendar.filters",
        fallback: fallback.excludedCalendarIDs
      ),
      includedCalendarSourceIDs: try optionalField(
        .stringArray("included_calendar_source_ids"),
        from: table,
        path: "builtins.calendar.filters",
        fallback: fallback.includedCalendarSourceIDs
      ),
      excludedCalendarSourceIDs: try optionalField(
        .stringArray("excluded_calendar_source_ids"),
        from: table,
        path: "builtins.calendar.filters",
        fallback: fallback.excludedCalendarSourceIDs
      )
    )
  }

  /// Parses appointment row display settings.
  func parseCalendarAppointments(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Appointments
  ) throws -> CalendarBuiltinConfig.Appointments {
    CalendarBuiltinConfig.Appointments(
      itemIndent: try optionalField(
        .number("item_indent"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.itemIndent
      ),
      eventTextColorHex: try optionalField(
        .string("event_text_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.eventTextColorHex
      ),
      emptyTextColorHex: try optionalField(
        .string("empty_text_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.emptyTextColorHex
      ),
      secondaryTextColorHex: try optionalField(
        .string("secondary_text_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.secondaryTextColorHex
      ),
      travelTextColorHex: try optionalField(
        .string("travel_text_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.travelTextColorHex
      ),
      emptyText: try optionalField(
        .string("empty_text"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.emptyText
      ),
      showCalendarName: try optionalField(
        .bool("show_calendar_name"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showCalendarName
      ),
      showAllDayLabel: try optionalField(
        .bool("show_all_day_label"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showAllDayLabel
      ),
      showHolidayAllDayLabel: try optionalField(
        .bool("show_holiday_all_day_label"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showHolidayAllDayLabel
      ),
      allDayLabel: try optionalField(
        .string("all_day_label"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.allDayLabel
      ),
      showLocation: try optionalField(
        .bool("show_location"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showLocation
      ),
      locationIcon: try optionalField(
        .string("location_icon"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.locationIcon
      ),
      locationIconColorHex: try optionalField(
        .string("location_icon_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.locationIconColorHex
      ),
      showTravelTime: try optionalField(
        .bool("show_travel_time"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showTravelTime
      ),
      showEndTime: try optionalField(
        .bool("show_end_time"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showEndTime
      ),
      travelIcon: try optionalField(
        .string("travel_icon"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.travelIcon
      ),
      travelIconColorHex: try optionalField(
        .string("travel_icon_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.travelIconColorHex
      ),
      showAlertIcon: try optionalField(
        .bool("show_alert_icon"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.showAlertIcon
      ),
      alertIcon: try optionalField(
        .string("alert_icon"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.alertIcon
      ),
      alertIconColorHex: try optionalField(
        .string("alert_icon_color"),
        from: table,
        path: "builtins.calendar.appointments",
        fallback: fallback.alertIconColorHex
      )
    )
  }

  /// Parses birthday display settings.
  func parseCalendarBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      showBirthdays: try optionalField(
        .bool("show_birthdays"),
        from: table,
        path: "builtins.calendar.birthdays",
        fallback: fallback.showBirthdays
      ),
      birthdaysShowAge: try optionalField(
        .bool("birthdays_show_age"),
        from: table,
        path: "builtins.calendar.birthdays",
        fallback: fallback.birthdaysShowAge
      ),
      birthdayIcon: try optionalField(
        .string("birthday_icon"),
        from: table,
        path: "builtins.calendar.birthdays",
        fallback: fallback.birthdayIcon
      ),
      birthdayIconColorHex: try optionalField(
        .string("birthday_icon_color"),
        from: table,
        path: "builtins.calendar.birthdays",
        fallback: fallback.birthdayIconColorHex
      )
    )
  }
}

extension CalendarBuiltinConfig {
  /// Returns a copy with all calendar color references resolved to concrete hex values.
  fileprivate func resolvingThemeColorReferences(
    using resolve: (String) -> String
  ) -> CalendarBuiltinConfig {
    var config = self

    config.style.textColorHex = config.style.textColorHex.map(resolve)
    config.style.backgroundColorHex = config.style.backgroundColorHex.map(resolve)
    config.style.borderColorHex = config.style.borderColorHex.map(resolve)

    config.anchor.topTextColorHex = config.anchor.topTextColorHex.map(resolve)
    config.anchor.bottomTextColorHex = config.anchor.bottomTextColorHex.map(resolve)

    config.appointments.eventTextColorHex = resolve(config.appointments.eventTextColorHex)
    config.appointments.emptyTextColorHex = resolve(config.appointments.emptyTextColorHex)
    config.appointments.secondaryTextColorHex = resolve(config.appointments.secondaryTextColorHex)
    config.appointments.travelTextColorHex = resolve(config.appointments.travelTextColorHex)
    config.appointments.locationIconColorHex = config.appointments.locationIconColorHex.map(resolve)
    config.appointments.travelIconColorHex = config.appointments.travelIconColorHex.map(resolve)
    config.appointments.alertIconColorHex = config.appointments.alertIconColorHex.map(resolve)

    config.birthdays.birthdayIconColorHex = config.birthdays.birthdayIconColorHex.map(resolve)

    config.composer.style.backgroundColorHex = resolve(config.composer.style.backgroundColorHex)
    config.composer.style.borderColorHex = resolve(config.composer.style.borderColorHex)
    config.composer.style.headerTextColorHex = resolve(config.composer.style.headerTextColorHex)

    config.upcoming.popup.backgroundColorHex = resolve(config.upcoming.popup.backgroundColorHex)
    config.upcoming.popup.borderColorHex = resolve(config.upcoming.popup.borderColorHex)

    config.month.popup.style.backgroundColorHex = resolve(
      config.month.popup.style.backgroundColorHex)
    config.month.popup.style.borderColorHex = resolve(config.month.popup.style.borderColorHex)

    config.month.popup.calendar.headerTextColorHex = resolve(
      config.month.popup.calendar.headerTextColorHex
    )
    config.month.popup.calendar.weekdayTextColorHex = resolve(
      config.month.popup.calendar.weekdayTextColorHex
    )
    config.month.popup.calendar.dayTextColorHex = resolve(
      config.month.popup.calendar.dayTextColorHex
    )
    config.month.popup.calendar.outsideMonthTextColorHex = resolve(
      config.month.popup.calendar.outsideMonthTextColorHex
    )
    config.month.popup.calendar.todayCellBackgroundColorHex = resolve(
      config.month.popup.calendar.todayCellBackgroundColorHex
    )
    config.month.popup.calendar.todayCellBorderColorHex = resolve(
      config.month.popup.calendar.todayCellBorderColorHex
    )
    config.month.popup.calendar.indicatorColorHex = resolve(
      config.month.popup.calendar.indicatorColorHex
    )

    config.month.popup.selection.selectedTextColorHex = resolve(
      config.month.popup.selection.selectedTextColorHex
    )
    config.month.popup.selection.selectedBackgroundColorHex = resolve(
      config.month.popup.selection.selectedBackgroundColorHex
    )

    config.month.popup.anchor.textColorHex = config.month.popup.anchor.textColorHex.map(resolve)
    config.month.popup.todayButton.borderColorHex = resolve(
      config.month.popup.todayButton.borderColorHex
    )

    return config
  }
}
