import EasyBarShared
import Foundation
import TOMLKit

extension CalendarBuiltinConfig {
  /// Parses one calendar config table using the provided fallback for missing values.
  public static func parse(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig = .default,
    path: String = "builtins.calendar"
  ) throws -> CalendarBuiltinConfig {
    let parser = CalendarBuiltinConfigParser(rootPath: path)

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
      placement: try parser.parsePlacement(
        from: table,
        path: path,
        fallback: fallback.placement
      ),
      style: try parser.parseWidgetStyle(
        from: styleTable,
        path: "\(path).style",
        fallback: fallback.style
      ),
      popupMode: try parser.parseCalendarPopupMode(
        try parser.optionalString(table["popup_mode"], path: "\(path).popup_mode")
          ?? fallback.popupMode.rawValue,
        path: "\(path).popup_mode"
      ),
      anchor: try parser.parseAnchor(
        from: anchorTable,
        fallback: fallback.anchor
      ),
      filters: try parser.parseFilters(
        from: filtersTable,
        fallback: fallback.filters
      ),
      appointments: try parser.parseAppointments(
        from: appointmentsTable,
        fallback: fallback.appointments
      ),
      birthdays: try parser.parseBirthdays(
        from: birthdaysTable,
        fallback: fallback.birthdays
      ),
      composer: try parser.parseComposer(
        from: composerTable,
        fallback: fallback.composer
      ),
      upcoming: try parser.parseUpcoming(
        eventsTable: upcomingEventsTable,
        popupTable: upcomingPopupTable,
        fallback: fallback.upcoming
      ),
      month: try parser.parseMonth(
        popupTable: monthPopupTable,
        fallback: fallback.month
      )
    )
  }
}

/// Parser implementation for `CalendarBuiltinConfig`.
private struct CalendarBuiltinConfigParser {
  let rootPath: String

  // MARK: - Top-level shared blocks

  /// Parses shared widget placement fields.
  func parsePlacement(
    from table: TOMLTable,
    path: String,
    fallback: CalendarWidgetPlacement
  ) throws -> CalendarWidgetPlacement {
    CalendarWidgetPlacement(
      enabled: try optionalBool(table["enabled"], path: "\(path).enabled") ?? fallback.enabled,
      position: try parseWidgetPosition(
        try optionalString(table["position"], path: "\(path).position")
          ?? fallback.position.rawValue,
        path: "\(path).position"
      ),
      order: try optionalInt(table["order"], path: "\(path).order") ?? fallback.order,
      group: try optionalString(table["group"], path: "\(path).group") ?? fallback.group
    )
  }

  /// Parses shared widget style fields.
  func parseWidgetStyle(
    from table: TOMLTable,
    path: String,
    fallback: CalendarWidgetStyle
  ) throws -> CalendarWidgetStyle {
    CalendarWidgetStyle(
      icon: try optionalString(table["icon"], path: "\(path).icon") ?? fallback.icon,
      textColorHex: try optionalString(table["text_color"], path: "\(path).text_color")
        ?? fallback.textColorHex,
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(path).background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(table["border_color"], path: "\(path).border_color")
        ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(table["border_width"], path: "\(path).border_width")
        ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(table["corner_radius"], path: "\(path).corner_radius")
        ?? fallback.cornerRadius,
      marginX: try optionalNumber(table["margin_x"], path: "\(path).margin_x")
        ?? fallback.marginX,
      marginY: try optionalNumber(table["margin_y"], path: "\(path).margin_y")
        ?? fallback.marginY,
      paddingX: try optionalNumber(table["padding_x"], path: "\(path).padding_x")
        ?? fallback.paddingX,
      paddingY: try optionalNumber(table["padding_y"], path: "\(path).padding_y")
        ?? fallback.paddingY,
      spacing: try optionalNumber(table["spacing"], path: "\(path).spacing")
        ?? fallback.spacing,
      opacity: try optionalNumber(table["opacity"], path: "\(path).opacity")
        ?? fallback.opacity
    )
  }

  /// Parses the calendar anchor block.
  func parseAnchor(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Anchor
  ) throws -> CalendarBuiltinConfig.Anchor {
    CalendarBuiltinConfig.Anchor(
      itemFormat: try optionalString(
        table["item_format"],
        path: "\(rootPath).anchor.item_format"
      ) ?? fallback.itemFormat,
      layout: try parseCalendarLayout(
        try optionalString(table["layout"], path: "\(rootPath).anchor.layout")
          ?? fallback.layout.rawValue,
        path: "\(rootPath).anchor.layout"
      ),
      topFormat: try optionalString(
        table["top_format"],
        path: "\(rootPath).anchor.top_format"
      ) ?? fallback.topFormat,
      bottomFormat: try optionalString(
        table["bottom_format"],
        path: "\(rootPath).anchor.bottom_format"
      ) ?? fallback.bottomFormat,
      lineSpacing: try optionalNumber(
        table["line_spacing"],
        path: "\(rootPath).anchor.line_spacing"
      ) ?? fallback.lineSpacing,
      topTextColorHex: try optionalString(
        table["top_text_color"],
        path: "\(rootPath).anchor.top_text_color"
      ) ?? fallback.topTextColorHex,
      bottomTextColorHex: try optionalString(
        table["bottom_text_color"],
        path: "\(rootPath).anchor.bottom_text_color"
      ) ?? fallback.bottomTextColorHex
    )
  }

  /// Parses calendar include/exclude filters.
  func parseFilters(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Filters
  ) throws -> CalendarBuiltinConfig.Filters {
    CalendarBuiltinConfig.Filters(
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "\(rootPath).filters.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "\(rootPath).filters.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames,
      includedCalendarIDs: try optionalStringArray(
        table["included_calendar_ids"],
        path: "\(rootPath).filters.included_calendar_ids"
      ) ?? fallback.includedCalendarIDs,
      excludedCalendarIDs: try optionalStringArray(
        table["excluded_calendar_ids"],
        path: "\(rootPath).filters.excluded_calendar_ids"
      ) ?? fallback.excludedCalendarIDs,
      includedCalendarSourceIDs: try optionalStringArray(
        table["included_calendar_source_ids"],
        path: "\(rootPath).filters.included_calendar_source_ids"
      ) ?? fallback.includedCalendarSourceIDs,
      excludedCalendarSourceIDs: try optionalStringArray(
        table["excluded_calendar_source_ids"],
        path: "\(rootPath).filters.excluded_calendar_source_ids"
      ) ?? fallback.excludedCalendarSourceIDs
    )
  }

  /// Parses appointment row display settings.
  func parseAppointments(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Appointments
  ) throws -> CalendarBuiltinConfig.Appointments {
    CalendarBuiltinConfig.Appointments(
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "\(rootPath).appointments.item_indent"
      ) ?? fallback.itemIndent,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "\(rootPath).appointments.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "\(rootPath).appointments.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "\(rootPath).appointments.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      travelTextColorHex: try optionalString(
        table["travel_text_color"],
        path: "\(rootPath).appointments.travel_text_color"
      ) ?? fallback.travelTextColorHex,
      emptyText: try optionalString(
        table["empty_text"],
        path: "\(rootPath).appointments.empty_text"
      ) ?? fallback.emptyText,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "\(rootPath).appointments.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "\(rootPath).appointments.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      showHolidayAllDayLabel: try optionalBool(
        table["show_holiday_all_day_label"],
        path: "\(rootPath).appointments.show_holiday_all_day_label"
      ) ?? fallback.showHolidayAllDayLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "\(rootPath).appointments.all_day_label"
      ) ?? fallback.allDayLabel,
      showLocation: try optionalBool(
        table["show_location"],
        path: "\(rootPath).appointments.show_location"
      ) ?? fallback.showLocation,
      showTravelTime: try optionalBool(
        table["show_travel_time"],
        path: "\(rootPath).appointments.show_travel_time"
      ) ?? fallback.showTravelTime,
      showEndTime: try optionalBool(
        table["show_end_time"],
        path: "\(rootPath).appointments.show_end_time"
      ) ?? fallback.showEndTime,
      travelIcon: try optionalString(
        table["travel_icon"],
        path: "\(rootPath).appointments.travel_icon"
      ) ?? fallback.travelIcon,
      travelIconColorHex: try optionalString(
        table["travel_icon_color"],
        path: "\(rootPath).appointments.travel_icon_color"
      ) ?? fallback.travelIconColorHex,
      showAlertIcon: try optionalBool(
        table["show_alert_icon"],
        path: "\(rootPath).appointments.show_alert_icon"
      ) ?? fallback.showAlertIcon,
      alertIcon: try optionalString(
        table["alert_icon"],
        path: "\(rootPath).appointments.alert_icon"
      ) ?? fallback.alertIcon,
      alertIconColorHex: try optionalString(
        table["alert_icon_color"],
        path: "\(rootPath).appointments.alert_icon_color"
      ) ?? fallback.alertIconColorHex
    )
  }

  /// Parses birthday display settings.
  func parseBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      showBirthdays: try optionalBool(
        table["show_birthdays"],
        path: "\(rootPath).birthdays.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        table["birthdays_show_age"],
        path: "\(rootPath).birthdays.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        table["birthday_icon"],
        path: "\(rootPath).birthdays.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        table["birthday_icon_color"],
        path: "\(rootPath).birthdays.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex
    )
  }

  // MARK: - Composer

  /// Parses the shared event composer config.
  func parseComposer(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer
  ) throws -> CalendarBuiltinConfig.Composer {
    let styleTable = table["style"]?.table ?? TOMLTable()
    let alertLabelsTable = table["alert_labels"]?.table ?? TOMLTable()
    let travelTimeLabelsTable = table["travel_time_labels"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Composer(
      style: try parseComposerStyle(from: styleTable, fallback: fallback.style),
      content: try parseComposerContent(
        from: table,
        alertLabelsTable: alertLabelsTable,
        travelTimeLabelsTable: travelTimeLabelsTable,
        fallback: fallback.content
      )
    )
  }

  /// Parses event composer style fields.
  func parseComposerStyle(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer.Style
  ) throws -> CalendarBuiltinConfig.Composer.Style {
    CalendarBuiltinConfig.Composer.Style(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(rootPath).composer.style.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "\(rootPath).composer.style.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "\(rootPath).composer.style.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "\(rootPath).composer.style.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "\(rootPath).composer.style.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "\(rootPath).composer.style.padding_y"
      ) ?? fallback.paddingY,
      headerTextColorHex: try optionalString(
        table["header_text_color"],
        path: "\(rootPath).composer.style.header_text_color"
      ) ?? fallback.headerTextColorHex
    )
  }

  /// Parses event composer labels and defaults.
  func parseComposerContent(
    from table: TOMLTable,
    alertLabelsTable: TOMLTable,
    travelTimeLabelsTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Composer.Content
  ) throws -> CalendarBuiltinConfig.Composer.Content {
    CalendarBuiltinConfig.Composer.Content(
      createTitle: try optionalString(
        table["create_title"],
        path: "\(rootPath).composer.create_title"
      ) ?? fallback.createTitle,
      editTitle: try optionalString(
        table["edit_title"],
        path: "\(rootPath).composer.edit_title"
      ) ?? fallback.editTitle,
      titleLabel: try optionalString(
        table["title_label"],
        path: "\(rootPath).composer.title_label"
      ) ?? fallback.titleLabel,
      locationLabel: try optionalString(
        table["location_label"],
        path: "\(rootPath).composer.location_label"
      ) ?? fallback.locationLabel,
      calendarLabel: try optionalString(
        table["calendar_label"],
        path: "\(rootPath).composer.calendar_label"
      ) ?? fallback.calendarLabel,
      titlePlaceholder: try optionalString(
        table["title_placeholder"],
        path: "\(rootPath).composer.title_placeholder"
      ) ?? fallback.titlePlaceholder,
      locationPlaceholder: try optionalString(
        table["location_placeholder"],
        path: "\(rootPath).composer.location_placeholder"
      ) ?? fallback.locationPlaceholder,
      defaultCalendarName: try optionalString(
        table["default_calendar_name"],
        path: "\(rootPath).composer.default_calendar_name"
      ) ?? fallback.defaultCalendarName,
      defaultAlert: try optionalString(
        table["default_alert"],
        path: "\(rootPath).composer.default_alert"
      ) ?? fallback.defaultAlert,
      defaultTravelTime: try optionalString(
        table["default_travel_time"],
        path: "\(rootPath).composer.default_travel_time"
      ) ?? fallback.defaultTravelTime,
      alertLabels: try optionalStringMap(alertLabelsTable) ?? fallback.alertLabels,
      travelTimeLabels: try optionalStringMap(travelTimeLabelsTable) ?? fallback.travelTimeLabels,
      startLabel: try optionalString(
        table["start_label"],
        path: "\(rootPath).composer.start_label"
      ) ?? fallback.startLabel,
      endLabel: try optionalString(
        table["end_label"],
        path: "\(rootPath).composer.end_label"
      ) ?? fallback.endLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "\(rootPath).composer.all_day_label"
      ) ?? fallback.allDayLabel,
      travelTimeLabel: try optionalString(
        table["travel_time_label"],
        path: "\(rootPath).composer.travel_time_label"
      ) ?? fallback.travelTimeLabel,
      alertLabel: try optionalString(
        table["alert_label"],
        path: "\(rootPath).composer.alert_label"
      ) ?? fallback.alertLabel,
      addAlertLabel: try optionalString(
        table["add_alert_label"],
        path: "\(rootPath).composer.add_alert_label"
      ) ?? fallback.addAlertLabel,
      openCalendarLabel: try optionalString(
        table["open_calendar_label"],
        path: "\(rootPath).composer.open_calendar_label"
      ) ?? fallback.openCalendarLabel,
      cancelLabel: try optionalString(
        table["cancel_label"],
        path: "\(rootPath).composer.cancel_label"
      ) ?? fallback.cancelLabel,
      saveLabel: try optionalString(
        table["save_label"],
        path: "\(rootPath).composer.save_label"
      ) ?? fallback.saveLabel,
      updateLabel: try optionalString(
        table["update_label"],
        path: "\(rootPath).composer.update_label"
      ) ?? fallback.updateLabel,
      removeLabel: try optionalString(
        table["remove_label"],
        path: "\(rootPath).composer.remove_label"
      ) ?? fallback.removeLabel,
      deleteConfirmationTitle: try optionalString(
        table["delete_confirmation_title"],
        path: "\(rootPath).composer.delete_confirmation_title"
      ) ?? fallback.deleteConfirmationTitle,
      deleteConfirmationMessage: try optionalString(
        table["delete_confirmation_message"],
        path: "\(rootPath).composer.delete_confirmation_message"
      ) ?? fallback.deleteConfirmationMessage
    )
  }

  // MARK: - Upcoming

  /// Parses upcoming mode config.
  func parseUpcoming(
    eventsTable: TOMLTable,
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming
  ) throws -> CalendarBuiltinConfig.Upcoming {
    CalendarBuiltinConfig.Upcoming(
      events: try parseUpcomingEvents(from: eventsTable, fallback: fallback.events),
      popup: try parseUpcomingPopup(from: popupTable, fallback: fallback.popup)
    )
  }

  /// Parses upcoming event query settings.
  func parseUpcomingEvents(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Events
  ) throws -> CalendarBuiltinConfig.Upcoming.Events {
    CalendarBuiltinConfig.Upcoming.Events(
      days: max(
        1,
        try optionalInt(
          table["days"],
          path: "\(rootPath).upcoming.events.days"
        ) ?? fallback.days
      ),
      excludePastEvents: try optionalBool(
        table["exclude_past_events"],
        path: "\(rootPath).upcoming.events.exclude_past_events"
      ) ?? fallback.excludePastEvents
    )
  }

  /// Parses upcoming popup style settings.
  func parseUpcomingPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Popup
  ) throws -> CalendarBuiltinConfig.Upcoming.Popup {
    CalendarBuiltinConfig.Upcoming.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "\(rootPath).upcoming.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "\(rootPath).upcoming.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "\(rootPath).upcoming.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "\(rootPath).upcoming.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "\(rootPath).upcoming.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "\(rootPath).upcoming.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "\(rootPath).upcoming.popup.spacing"
      ) ?? fallback.spacing,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "\(rootPath).upcoming.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "\(rootPath).upcoming.popup.margin_y"
      ) ?? fallback.marginY
    )
  }

  // MARK: - Month

  /// Parses month mode config.
  func parseMonth(
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month
  ) throws -> CalendarBuiltinConfig.Month {
    CalendarBuiltinConfig.Month(
      popup: try parseMonthPopup(from: popupTable, fallback: fallback.popup)
    )
  }

  /// Parses the month popup block.
  func parseMonthPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup
  ) throws -> CalendarBuiltinConfig.Month.Popup {
    let styleTable = table["style"]?.table ?? TOMLTable()
    let calendarTable = table["calendar"]?.table ?? TOMLTable()
    let selectionTable = table["selection"]?.table ?? TOMLTable()
    let agendaTable = table["agenda"]?.table ?? TOMLTable()
    let anchorTable = table["anchor"]?.table ?? TOMLTable()
    let todayButtonTable = table["today_button"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Month.Popup(
      style: try parseMonthPopupStyle(
        from: styleTable,
        rootTable: table,
        fallback: fallback.style
      ),
      calendar: try parseMonthPopupCalendar(
        from: calendarTable,
        rootTable: table,
        fallback: fallback.calendar
      ),
      selection: try parseMonthPopupSelection(
        from: selectionTable,
        rootTable: table,
        fallback: fallback.selection
      ),
      agenda: try parseMonthPopupAgenda(
        from: agendaTable,
        rootTable: table,
        fallback: fallback.agenda
      ),
      anchor: try parseMonthPopupAnchor(
        from: anchorTable,
        rootTable: table,
        fallback: fallback.anchor
      ),
      todayButton: try parseMonthPopupTodayButton(
        from: todayButtonTable,
        rootTable: table,
        fallback: fallback.todayButton
      )
    )
  }

  /// Parses month popup container style.
  func parseMonthPopupStyle(
    from table: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.Style
  ) throws -> CalendarBuiltinConfig.Month.Popup.Style {
    CalendarBuiltinConfig.Month.Popup.Style(
      backgroundColorHex: try optionalString(
        table["background_color"] ?? rootTable["background_color"],
        path: "\(rootPath).month.popup.style.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"] ?? rootTable["border_color"],
        path: "\(rootPath).month.popup.style.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"] ?? rootTable["border_width"],
        path: "\(rootPath).month.popup.style.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"] ?? rootTable["corner_radius"],
        path: "\(rootPath).month.popup.style.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"] ?? rootTable["padding_x"],
        path: "\(rootPath).month.popup.style.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"] ?? rootTable["padding_y"],
        path: "\(rootPath).month.popup.style.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"] ?? rootTable["spacing"],
        path: "\(rootPath).month.popup.style.spacing"
      ) ?? fallback.spacing,
      marginX: try optionalNumber(
        table["margin_x"] ?? rootTable["margin_x"],
        path: "\(rootPath).month.popup.style.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"] ?? rootTable["margin_y"],
        path: "\(rootPath).month.popup.style.margin_y"
      ) ?? fallback.marginY
    )
  }

  /// Parses month grid style and behavior.
  func parseMonthPopupCalendar(
    from table: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.CalendarStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.CalendarStyle {
    let weekdayFormat =
      try optionalString(
        table["weekday_format"] ?? rootTable["weekday_format"],
        path: "\(rootPath).month.popup.calendar.weekday_format"
      ) ?? fallback.weekdayFormat

    let weekdaySymbols =
      try optionalStringArray(
        table["weekday_symbols"] ?? rootTable["weekday_symbols"],
        path: "\(rootPath).month.popup.calendar.weekday_symbols"
      ) ?? fallback.weekdaySymbols

    return CalendarBuiltinConfig.Month.Popup.CalendarStyle(
      showWeekNumbers: try optionalBool(
        table["show_week_numbers"] ?? rootTable["show_week_numbers"],
        path: "\(rootPath).month.popup.calendar.show_week_numbers"
      ) ?? fallback.showWeekNumbers,
      showEventIndicators: try optionalBool(
        table["show_event_indicators"] ?? rootTable["show_event_indicators"],
        path: "\(rootPath).month.popup.calendar.show_event_indicators"
      ) ?? fallback.showEventIndicators,
      headerTextColorHex: try optionalString(
        table["header_text_color"] ?? rootTable["header_text_color"],
        path: "\(rootPath).month.popup.calendar.header_text_color"
      ) ?? fallback.headerTextColorHex,
      weekdayTextColorHex: try optionalString(
        table["weekday_text_color"] ?? rootTable["weekday_text_color"],
        path: "\(rootPath).month.popup.calendar.weekday_text_color"
      ) ?? fallback.weekdayTextColorHex,
      firstWeekday: try optionalInt(
        table["first_weekday"] ?? rootTable["first_weekday"],
        path: "\(rootPath).month.popup.calendar.first_weekday"
      ) ?? fallback.firstWeekday,
      weekdayFormat: weekdayFormat,
      weekdaySymbols: weekdaySymbols,
      resolvedWeekdaySymbols: CalendarBuiltinConfig.resolveMonthWeekdaySymbols(
        format: weekdayFormat,
        manualSymbols: weekdaySymbols
      ),
      dayTextColorHex: try optionalString(
        table["day_text_color"] ?? rootTable["day_text_color"],
        path: "\(rootPath).month.popup.calendar.day_text_color"
      ) ?? fallback.dayTextColorHex,
      outsideMonthTextColorHex: try optionalString(
        table["outside_month_text_color"] ?? rootTable["outside_month_text_color"],
        path: "\(rootPath).month.popup.calendar.outside_month_text_color"
      ) ?? fallback.outsideMonthTextColorHex,
      todayCellBackgroundColorHex: try optionalString(
        table["today_cell_background_color"] ?? rootTable["today_cell_background_color"],
        path: "\(rootPath).month.popup.calendar.today_cell_background_color"
      ) ?? fallback.todayCellBackgroundColorHex,
      todayCellBorderColorHex: try optionalString(
        table["today_cell_border_color"] ?? rootTable["today_cell_border_color"],
        path: "\(rootPath).month.popup.calendar.today_cell_border_color"
      ) ?? fallback.todayCellBorderColorHex,
      todayCellBorderWidth: try optionalNumber(
        table["today_cell_border_width"] ?? rootTable["today_cell_border_width"],
        path: "\(rootPath).month.popup.calendar.today_cell_border_width"
      ) ?? fallback.todayCellBorderWidth,
      indicatorColorHex: try optionalString(
        table["indicator_color"] ?? rootTable["indicator_color"],
        path: "\(rootPath).month.popup.calendar.indicator_color"
      ) ?? fallback.indicatorColorHex
    )
  }

  /// Parses month selection settings.
  func parseMonthPopupSelection(
    from table: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.SelectionStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.SelectionStyle {
    CalendarBuiltinConfig.Month.Popup.SelectionStyle(
      selectedTextColorHex: try optionalString(
        table["selected_text_color"] ?? rootTable["selected_text_color"],
        path: "\(rootPath).month.popup.selection.selected_text_color"
      ) ?? fallback.selectedTextColorHex,
      selectedBackgroundColorHex: try optionalString(
        table["selected_background_color"] ?? rootTable["selected_background_color"],
        path: "\(rootPath).month.popup.selection.selected_background_color"
      ) ?? fallback.selectedBackgroundColorHex,
      selectionDateFormat: try optionalString(
        table["selection_date_format"] ?? rootTable["selection_date_format"],
        path: "\(rootPath).month.popup.selection.selection_date_format"
      ) ?? fallback.selectionDateFormat,
      selectionDateSeparator: try optionalString(
        table["selection_date_separator"] ?? rootTable["selection_date_separator"],
        path: "\(rootPath).month.popup.selection.selection_date_separator"
      ) ?? fallback.selectionDateSeparator,
      allowsRangeSelection: try optionalBool(
        table["allows_range_selection"] ?? rootTable["allows_range_selection"],
        path: "\(rootPath).month.popup.selection.allows_range_selection"
      ) ?? fallback.allowsRangeSelection,
      resetSelectionOnThirdTap: try optionalBool(
        table["reset_selection_on_third_tap"] ?? rootTable["reset_selection_on_third_tap"],
        path: "\(rootPath).month.popup.selection.reset_selection_on_third_tap"
      ) ?? fallback.resetSelectionOnThirdTap
    )
  }

  /// Parses month agenda settings.
  func parseMonthPopupAgenda(
    from table: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.AgendaStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.AgendaStyle {
    let parsedMinHeight =
      try optionalNumber(
        table["appointments_min_height"] ?? rootTable["appointments_min_height"],
        path: "\(rootPath).month.popup.agenda.appointments_min_height"
      ) ?? fallback.appointmentsMinHeight

    let parsedMaxHeight =
      try optionalNumber(
        table["appointments_max_height"] ?? rootTable["appointments_max_height"],
        path: "\(rootPath).month.popup.agenda.appointments_max_height"
      ) ?? fallback.appointmentsMaxHeight

    let minHeight = max(0, min(parsedMinHeight, parsedMaxHeight))
    let maxHeight = max(parsedMinHeight, parsedMaxHeight)

    return CalendarBuiltinConfig.Month.Popup.AgendaStyle(
      layout: try parseMonthLayout(
        try optionalString(
          table["layout"] ?? rootTable["layout"],
          path: "\(rootPath).month.popup.agenda.layout"
        ) ?? fallback.layout.rawValue,
        path: "\(rootPath).month.popup.agenda.layout"
      ),
      appointmentsScrollable: try optionalBool(
        table["appointments_scrollable"] ?? rootTable["appointments_scrollable"],
        path: "\(rootPath).month.popup.agenda.appointments_scrollable"
      ) ?? fallback.appointmentsScrollable,
      appointmentsMinHeight: minHeight,
      appointmentsMaxHeight: maxHeight,
      agendaTitle: try optionalString(
        table["agenda_title"] ?? rootTable["agenda_title"],
        path: "\(rootPath).month.popup.agenda.agenda_title"
      ) ?? fallback.agendaTitle,
      maxVisibleAppointments: max(
        1,
        try optionalInt(
          table["max_visible_appointments"] ?? rootTable["max_visible_appointments"],
          path: "\(rootPath).month.popup.agenda.max_visible_appointments"
        ) ?? fallback.maxVisibleAppointments
      )
    )
  }

  /// Parses month selected-date anchor settings.
  func parseMonthPopupAnchor(
    from table: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.AnchorStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.AnchorStyle {
    CalendarBuiltinConfig.Month.Popup.AnchorStyle(
      dateFormat: try optionalString(
        table["date_format"] ?? rootTable["anchor_date_format"],
        path: "\(rootPath).month.popup.anchor.date_format"
      ) ?? fallback.dateFormat,
      textColorHex: try optionalString(
        table["text_color"] ?? rootTable["anchor_text_color"],
        path: "\(rootPath).month.popup.anchor.text_color"
      ) ?? fallback.textColorHex,
      showDateText: try optionalBool(
        table["show_date_text"] ?? rootTable["anchor_show_date_text"],
        path: "\(rootPath).month.popup.anchor.show_date_text"
      ) ?? fallback.showDateText
    )
  }

  /// Parses month today-button settings.
  func parseMonthPopupTodayButton(
    from table: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.TodayButtonStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.TodayButtonStyle {
    CalendarBuiltinConfig.Month.Popup.TodayButtonStyle(
      title: try optionalString(
        table["title"] ?? rootTable["today_button_title"],
        path: "\(rootPath).month.popup.today_button.title"
      ) ?? fallback.title,
      icon: try optionalString(
        table["icon"] ?? rootTable["today_button_icon"],
        path: "\(rootPath).month.popup.today_button.icon"
      ) ?? fallback.icon,
      borderColorHex: try optionalString(
        table["border_color"] ?? rootTable["today_button_border_color"],
        path: "\(rootPath).month.popup.today_button.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"] ?? rootTable["today_button_border_width"],
        path: "\(rootPath).month.popup.today_button.border_width"
      ) ?? fallback.borderWidth
    )
  }

  // MARK: - Enum parsing

  /// Parses one widget position.
  func parseWidgetPosition(_ value: String, path: String) throws -> WidgetPosition {
    guard let position = WidgetPosition(rawValue: value) else {
      throw invalid(path: path, expected: "one of left, center, right", actual: value)
    }

    return position
  }

  /// Parses the calendar popup mode.
  func parseCalendarPopupMode(_ value: String, path: String) throws -> CalendarPopupMode {
    guard let mode = CalendarPopupMode(rawValue: value) else {
      throw invalid(path: path, expected: "none, upcoming, or month", actual: value)
    }

    return mode
  }

  /// Parses the calendar anchor layout.
  func parseCalendarLayout(_ value: String, path: String) throws -> CalendarAnchorLayout {
    guard let layout = CalendarAnchorLayout(rawValue: value) else {
      throw invalid(path: path, expected: "item, stack, or inline", actual: value)
    }

    return layout
  }

  /// Parses the month popup layout.
  func parseMonthLayout(_ value: String, path: String) throws -> MonthCalendarPopupLayout {
    guard let layout = MonthCalendarPopupLayout(rawValue: value) else {
      throw invalid(
        path: path,
        expected:
          "calendar_appointments_horizontal, appointments_calendar_horizontal, calendar_appointments_vertical, or appointments_calendar_vertical",
        actual: value
      )
    }

    return layout
  }

  // MARK: - TOML helpers

  /// Reads an optional TOML string.
  func optionalString(_ value: (any TOMLValueConvertible)?, path: String) throws -> String? {
    guard let value else { return nil }

    guard let string = value.string else {
      throw invalid(path: path, expected: "string", actual: String(describing: value))
    }

    return string
  }

  /// Reads an optional TOML bool.
  func optionalBool(_ value: (any TOMLValueConvertible)?, path: String) throws -> Bool? {
    guard let value else { return nil }

    guard let bool = value.bool else {
      throw invalid(path: path, expected: "bool", actual: String(describing: value))
    }

    return bool
  }

  /// Reads an optional TOML number.
  func optionalNumber(_ value: (any TOMLValueConvertible)?, path: String) throws -> Double? {
    guard let value else { return nil }

    if let double = value.double {
      return double
    }

    if let int = value.int {
      return Double(int)
    }

    throw invalid(path: path, expected: "number", actual: String(describing: value))
  }

  /// Reads an optional TOML integer.
  func optionalInt(_ value: (any TOMLValueConvertible)?, path: String) throws -> Int? {
    guard let value else { return nil }

    guard let int = value.int else {
      throw invalid(path: path, expected: "integer", actual: String(describing: value))
    }

    return int
  }

  /// Reads an optional TOML string array.
  func optionalStringArray(
    _ value: (any TOMLValueConvertible)?,
    path: String
  ) throws -> [String]? {
    guard let value else { return nil }

    guard let array = value.array else {
      throw invalid(path: path, expected: "array of strings", actual: String(describing: value))
    }

    return try array.enumerated().map { index, item in
      guard let string = item.string else {
        throw invalid(
          path: "\(path)[\(index)]",
          expected: "string",
          actual: String(describing: item)
        )
      }

      return string
    }
  }

  /// Reads a string map from one TOML table.
  func optionalStringMap(_ table: TOMLTable) throws -> [String: String]? {
    guard !table.keys.isEmpty else { return nil }

    var result: [String: String] = [:]

    for key in table.keys.sorted() {
      guard let value = table[key]?.string else {
        throw invalid(
          path: "\(rootPath).composer.\(key)",
          expected: "string",
          actual: String(describing: table[key] as Any)
        )
      }

      result[key] = value
    }

    return result
  }

  /// Builds one parser error.
  private func invalid(path: String, expected: String, actual: String) -> CalendarConfigError {
    CalendarConfigError(configPath: path, expected: expected, actual: actual)
  }
}
