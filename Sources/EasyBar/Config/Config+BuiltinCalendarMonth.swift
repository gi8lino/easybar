import Foundation
import TOMLKit

extension Config {

  /// Parses the month calendar mode.
  func parseCalendarMonth(
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month
  ) throws -> CalendarBuiltinConfig.Month {
    CalendarBuiltinConfig.Month(
      popup: try parseCalendarMonthPopup(
        from: popupTable,
        fallback: fallback.popup
      )
    )
  }

  /// Parses the month popup block.
  func parseCalendarMonthPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup
  ) throws -> CalendarBuiltinConfig.Month.Popup {
    let styleTable = table["style"]?.table ?? TOMLTable()
    let calendarTable = table["calendar"]?.table ?? TOMLTable()
    let selectionTable = table["selection"]?.table ?? TOMLTable()
    let agendaTable = table["agenda"]?.table ?? TOMLTable()
    let birthdaysTable = table["birthdays"]?.table ?? TOMLTable()
    let filtersTable = table["filters"]?.table ?? TOMLTable()
    let anchorTable = table["anchor"]?.table ?? TOMLTable()
    let composerTable = table["composer"]?.table ?? TOMLTable()
    let todayButtonTable = table["today_button"]?.table ?? TOMLTable()

    let parsedMinHeight =
      try optionalNumber(
        agendaTable["appointments_min_height"] ?? table["appointments_min_height"],
        path: "builtins.calendar.month.popup.agenda.appointments_min_height"
      ) ?? fallback.appointmentsMinHeight

    let parsedMaxHeight =
      try optionalNumber(
        agendaTable["appointments_max_height"] ?? table["appointments_max_height"],
        path: "builtins.calendar.month.popup.agenda.appointments_max_height"
      ) ?? fallback.appointmentsMaxHeight

    let minHeight = max(0, min(parsedMinHeight, parsedMaxHeight))
    let maxHeight = max(parsedMinHeight, parsedMaxHeight)

    let weekdayFormat = try validatedMonthWeekdayFormat(
      try optionalString(
        calendarTable["weekday_format"] ?? table["weekday_format"],
        path: "builtins.calendar.month.popup.calendar.weekday_format"
      ) ?? fallback.weekdayFormat,
      path: "builtins.calendar.month.popup.calendar.weekday_format"
    )

    let weekdaySymbols = try validatedMonthWeekdaySymbols(
      try optionalStringArray(
        calendarTable["weekday_symbols"] ?? table["weekday_symbols"],
        path: "builtins.calendar.month.popup.calendar.weekday_symbols"
      ) ?? fallback.weekdaySymbols,
      path: "builtins.calendar.month.popup.calendar.weekday_symbols"
    )

    let parsedFirstWeekday =
      try optionalInt(
        calendarTable["first_weekday"] ?? table["first_weekday"],
        path: "builtins.calendar.month.popup.calendar.first_weekday"
      ) ?? fallback.firstWeekday

    if let parsedFirstWeekday, !(1...7).contains(parsedFirstWeekday) {
      throw ConfigError.invalidValue(
        path: "builtins.calendar.month.popup.calendar.first_weekday",
        message: "expected integer from 1 to 7"
      )
    }

    let resolvedWeekdaySymbols = Self.resolveMonthWeekdaySymbols(
      format: weekdayFormat,
      manualSymbols: weekdaySymbols
    )

    return CalendarBuiltinConfig.Month.Popup(
      style: .init(
        backgroundColorHex: try optionalString(
          styleTable["background_color"] ?? table["background_color"],
          path: "builtins.calendar.month.popup.style.background_color"
        ) ?? fallback.backgroundColorHex,
        borderColorHex: try optionalString(
          styleTable["border_color"] ?? table["border_color"],
          path: "builtins.calendar.month.popup.style.border_color"
        ) ?? fallback.borderColorHex,
        borderWidth: try optionalNumber(
          styleTable["border_width"] ?? table["border_width"],
          path: "builtins.calendar.month.popup.style.border_width"
        ) ?? fallback.borderWidth,
        cornerRadius: try optionalNumber(
          styleTable["corner_radius"] ?? table["corner_radius"],
          path: "builtins.calendar.month.popup.style.corner_radius"
        ) ?? fallback.cornerRadius,
        paddingX: try optionalNumber(
          styleTable["padding_x"] ?? table["padding_x"],
          path: "builtins.calendar.month.popup.style.padding_x"
        ) ?? fallback.paddingX,
        paddingY: try optionalNumber(
          styleTable["padding_y"] ?? table["padding_y"],
          path: "builtins.calendar.month.popup.style.padding_y"
        ) ?? fallback.paddingY,
        spacing: try optionalNumber(
          styleTable["spacing"] ?? table["spacing"],
          path: "builtins.calendar.month.popup.style.spacing"
        ) ?? fallback.spacing,
        itemIndent: try optionalNumber(
          styleTable["item_indent"] ?? table["item_indent"],
          path: "builtins.calendar.month.popup.style.item_indent"
        ) ?? fallback.itemIndent,
        marginX: try optionalNumber(
          styleTable["margin_x"] ?? table["margin_x"],
          path: "builtins.calendar.month.popup.style.margin_x"
        ) ?? fallback.marginX,
        marginY: try optionalNumber(
          styleTable["margin_y"] ?? table["margin_y"],
          path: "builtins.calendar.month.popup.style.margin_y"
        ) ?? fallback.marginY
      ),
      calendar: .init(
        showWeekNumbers: try optionalBool(
          calendarTable["show_week_numbers"] ?? table["show_week_numbers"],
          path: "builtins.calendar.month.popup.calendar.show_week_numbers"
        ) ?? fallback.showWeekNumbers,
        showEventIndicators: try optionalBool(
          calendarTable["show_event_indicators"] ?? table["show_event_indicators"],
          path: "builtins.calendar.month.popup.calendar.show_event_indicators"
        ) ?? fallback.showEventIndicators,
        headerTextColorHex: try optionalString(
          calendarTable["header_text_color"] ?? table["header_text_color"],
          path: "builtins.calendar.month.popup.calendar.header_text_color"
        ) ?? fallback.headerTextColorHex,
        weekdayTextColorHex: try optionalString(
          calendarTable["weekday_text_color"] ?? table["weekday_text_color"],
          path: "builtins.calendar.month.popup.calendar.weekday_text_color"
        ) ?? fallback.weekdayTextColorHex,
        firstWeekday: parsedFirstWeekday,
        weekdayFormat: weekdayFormat,
        weekdaySymbols: weekdaySymbols,
        resolvedWeekdaySymbols: resolvedWeekdaySymbols,
        dayTextColorHex: try optionalString(
          calendarTable["day_text_color"] ?? table["day_text_color"],
          path: "builtins.calendar.month.popup.calendar.day_text_color"
        ) ?? fallback.dayTextColorHex,
        outsideMonthTextColorHex: try optionalString(
          calendarTable["outside_month_text_color"] ?? table["outside_month_text_color"],
          path: "builtins.calendar.month.popup.calendar.outside_month_text_color"
        ) ?? fallback.outsideMonthTextColorHex,
        todayBackgroundColorHex: try optionalString(
          calendarTable["today_background_color"] ?? table["today_background_color"],
          path: "builtins.calendar.month.popup.calendar.today_background_color"
        ) ?? fallback.todayBackgroundColorHex,
        todayBorderColorHex: try optionalString(
          calendarTable["today_border_color"] ?? table["today_border_color"],
          path: "builtins.calendar.month.popup.calendar.today_border_color"
        ) ?? fallback.todayBorderColorHex,
        todayBorderWidth: try optionalNumber(
          calendarTable["today_border_width"] ?? table["today_border_width"],
          path: "builtins.calendar.month.popup.calendar.today_border_width"
        ) ?? fallback.todayBorderWidth,
        indicatorColorHex: try optionalString(
          calendarTable["indicator_color"] ?? table["indicator_color"],
          path: "builtins.calendar.month.popup.calendar.indicator_color"
        ) ?? fallback.indicatorColorHex
      ),
      selection: .init(
        selectedTextColorHex: try optionalString(
          selectionTable["selected_text_color"] ?? table["selected_text_color"],
          path: "builtins.calendar.month.popup.selection.selected_text_color"
        ) ?? fallback.selectedTextColorHex,
        selectedBackgroundColorHex: try optionalString(
          selectionTable["selected_background_color"] ?? table["selected_background_color"],
          path: "builtins.calendar.month.popup.selection.selected_background_color"
        ) ?? fallback.selectedBackgroundColorHex,
        selectionDateFormat: try optionalString(
          selectionTable["selection_date_format"] ?? table["selection_date_format"],
          path: "builtins.calendar.month.popup.selection.selection_date_format"
        ) ?? fallback.selectionDateFormat,
        selectionDateSeparator: try optionalString(
          selectionTable["selection_date_separator"] ?? table["selection_date_separator"],
          path: "builtins.calendar.month.popup.selection.selection_date_separator"
        ) ?? fallback.selectionDateSeparator,
        allowsRangeSelection: try optionalBool(
          selectionTable["allows_range_selection"] ?? table["allows_range_selection"],
          path: "builtins.calendar.month.popup.selection.allows_range_selection"
        ) ?? fallback.allowsRangeSelection,
        resetSelectionOnThirdTap: try optionalBool(
          selectionTable["reset_selection_on_third_tap"] ?? table["reset_selection_on_third_tap"],
          path: "builtins.calendar.month.popup.selection.reset_selection_on_third_tap"
        ) ?? fallback.resetSelectionOnThirdTap
      ),
      agenda: .init(
        eventTextColorHex: try optionalString(
          agendaTable["event_text_color"] ?? table["event_text_color"],
          path: "builtins.calendar.month.popup.agenda.event_text_color"
        ) ?? fallback.eventTextColorHex,
        emptyTextColorHex: try optionalString(
          agendaTable["empty_text_color"] ?? table["empty_text_color"],
          path: "builtins.calendar.month.popup.agenda.empty_text_color"
        ) ?? fallback.emptyTextColorHex,
        secondaryTextColorHex: try optionalString(
          agendaTable["secondary_text_color"] ?? table["secondary_text_color"],
          path: "builtins.calendar.month.popup.agenda.secondary_text_color"
        ) ?? fallback.secondaryTextColorHex,
        travelTextColorHex: try optionalString(
          agendaTable["travel_text_color"] ?? table["travel_text_color"],
          path: "builtins.calendar.month.popup.agenda.travel_text_color"
        ) ?? fallback.travelTextColorHex,
        layout: MonthCalendarPopupLayout(
          rawValue: try optionalString(
            agendaTable["layout"] ?? table["layout"],
            path: "builtins.calendar.month.popup.agenda.layout"
          ) ?? fallback.layout.rawValue
        ) ?? fallback.layout,
        appointmentsScrollable: try optionalBool(
          agendaTable["appointments_scrollable"] ?? table["appointments_scrollable"],
          path: "builtins.calendar.month.popup.agenda.appointments_scrollable"
        ) ?? fallback.appointmentsScrollable,
        appointmentsMinHeight: minHeight,
        appointmentsMaxHeight: maxHeight,
        emptyText: try optionalString(
          agendaTable["empty_text"] ?? table["empty_text"],
          path: "builtins.calendar.month.popup.agenda.empty_text"
        ) ?? fallback.emptyText,
        agendaTitle: try optionalString(
          agendaTable["agenda_title"] ?? table["agenda_title"],
          path: "builtins.calendar.month.popup.agenda.agenda_title"
        ) ?? fallback.agendaTitle,
        showCalendarName: try optionalBool(
          agendaTable["show_calendar_name"] ?? table["show_calendar_name"],
          path: "builtins.calendar.month.popup.agenda.show_calendar_name"
        ) ?? fallback.showCalendarName,
        showAllDayLabel: try optionalBool(
          agendaTable["show_all_day_label"] ?? table["show_all_day_label"],
          path: "builtins.calendar.month.popup.agenda.show_all_day_label"
        ) ?? fallback.showAllDayLabel,
        showHolidayAllDayLabel: try optionalBool(
          agendaTable["show_holiday_all_day_label"] ?? table["show_holiday_all_day_label"],
          path: "builtins.calendar.month.popup.agenda.show_holiday_all_day_label"
        ) ?? fallback.showHolidayAllDayLabel,
        allDayLabel: try optionalString(
          agendaTable["all_day_label"] ?? table["all_day_label"],
          path: "builtins.calendar.month.popup.agenda.all_day_label"
        ) ?? fallback.allDayLabel,
        showLocation: try optionalBool(
          agendaTable["show_location"] ?? table["show_location"],
          path: "builtins.calendar.month.popup.agenda.show_location"
        ) ?? fallback.showLocation,
        showTravelTime: try optionalBool(
          agendaTable["show_travel_time"] ?? table["show_travel_time"],
          path: "builtins.calendar.month.popup.agenda.show_travel_time"
        ) ?? fallback.showTravelTime,
        travelIcon: try optionalString(
          agendaTable["travel_icon"] ?? table["travel_icon"],
          path: "builtins.calendar.month.popup.agenda.travel_icon"
        ) ?? fallback.travelIcon,
        travelIconColorHex: try optionalString(
          agendaTable["travel_icon_color"] ?? table["travel_icon_color"],
          path: "builtins.calendar.month.popup.agenda.travel_icon_color"
        ) ?? fallback.travelIconColorHex,
        showAlertIcon: try optionalBool(
          agendaTable["show_alert_icon"] ?? table["show_alert_icon"],
          path: "builtins.calendar.month.popup.agenda.show_alert_icon"
        ) ?? fallback.showAlertIcon,
        alertIcon: try optionalString(
          agendaTable["alert_icon"] ?? table["alert_icon"],
          path: "builtins.calendar.month.popup.agenda.alert_icon"
        ) ?? fallback.alertIcon,
        alertIconColorHex: try optionalString(
          agendaTable["alert_icon_color"] ?? table["alert_icon_color"],
          path: "builtins.calendar.month.popup.agenda.alert_icon_color"
        ) ?? fallback.alertIconColorHex,
        maxVisibleAppointments: max(
          1,
          try optionalInt(
            agendaTable["max_visible_appointments"] ?? table["max_visible_appointments"],
            path: "builtins.calendar.month.popup.agenda.max_visible_appointments"
          ) ?? fallback.maxVisibleAppointments
        )
      ),
      birthdays: .init(
        showBirthdays: try optionalBool(
          birthdaysTable["show_birthdays"] ?? table["show_birthdays"],
          path: "builtins.calendar.month.popup.birthdays.show_birthdays"
        ) ?? fallback.showBirthdays,
        birthdaysShowAge: try optionalBool(
          birthdaysTable["birthdays_show_age"] ?? table["birthdays_show_age"],
          path: "builtins.calendar.month.popup.birthdays.birthdays_show_age"
        ) ?? fallback.birthdaysShowAge,
        birthdayIcon: try optionalString(
          birthdaysTable["birthday_icon"] ?? table["birthday_icon"],
          path: "builtins.calendar.month.popup.birthdays.birthday_icon"
        ) ?? fallback.birthdayIcon,
        birthdayIconColorHex: try optionalString(
          birthdaysTable["birthday_icon_color"] ?? table["birthday_icon_color"],
          path: "builtins.calendar.month.popup.birthdays.birthday_icon_color"
        ) ?? fallback.birthdayIconColorHex
      ),
      filters: .init(
        includedCalendarNames: try optionalStringArray(
          filtersTable["included_calendar_names"] ?? table["included_calendar_names"],
          path: "builtins.calendar.month.popup.filters.included_calendar_names"
        ) ?? fallback.includedCalendarNames,
        excludedCalendarNames: try optionalStringArray(
          filtersTable["excluded_calendar_names"] ?? table["excluded_calendar_names"],
          path: "builtins.calendar.month.popup.filters.excluded_calendar_names"
        ) ?? fallback.excludedCalendarNames
      ),
      anchor: .init(
        dateFormat: try optionalString(
          anchorTable["anchor_date_format"] ?? table["anchor_date_format"],
          path: "builtins.calendar.month.popup.anchor.anchor_date_format"
        ) ?? fallback.anchorDateFormat,
        textColorHex: try optionalString(
          anchorTable["anchor_text_color"] ?? table["anchor_text_color"],
          path: "builtins.calendar.month.popup.anchor.anchor_text_color"
        ) ?? fallback.anchorTextColorHex,
        showDateText: try optionalBool(
          anchorTable["anchor_show_date_text"] ?? table["anchor_show_date_text"],
          path: "builtins.calendar.month.popup.anchor.anchor_show_date_text"
        ) ?? fallback.anchorShowDateText
      ),
      composer: .init(
        createTitle: try optionalString(
          composerTable["create_title"] ?? table["composer_create_title"],
          path: "builtins.calendar.month.popup.composer.create_title"
        ) ?? fallback.composerCreateTitle,
        editTitle: try optionalString(
          composerTable["edit_title"] ?? table["composer_edit_title"],
          path: "builtins.calendar.month.popup.composer.edit_title"
        ) ?? fallback.composerEditTitle,
        titleLabel: try optionalString(
          composerTable["title_label"] ?? table["composer_title_label"],
          path: "builtins.calendar.month.popup.composer.title_label"
        ) ?? fallback.composerTitleLabel,
        locationLabel: try optionalString(
          composerTable["location_label"] ?? table["composer_location_label"],
          path: "builtins.calendar.month.popup.composer.location_label"
        ) ?? fallback.composerLocationLabel,
        calendarLabel: try optionalString(
          composerTable["calendar_label"] ?? table["composer_calendar_label"],
          path: "builtins.calendar.month.popup.composer.calendar_label"
        ) ?? fallback.composerCalendarLabel,
        titlePlaceholder: try optionalString(
          composerTable["title_placeholder"] ?? table["composer_title_placeholder"],
          path: "builtins.calendar.month.popup.composer.title_placeholder"
        ) ?? fallback.composerTitlePlaceholder,
        locationPlaceholder: try optionalString(
          composerTable["location_placeholder"] ?? table["composer_location_placeholder"],
          path: "builtins.calendar.month.popup.composer.location_placeholder"
        ) ?? fallback.composerLocationPlaceholder,
        defaultCalendarName: try optionalString(
          composerTable["default_calendar_name"] ?? table["composer_default_calendar_name"],
          path: "builtins.calendar.month.popup.composer.default_calendar_name"
        ) ?? fallback.composerDefaultCalendarName,
        defaultAlert: try optionalString(
          composerTable["default_alert"] ?? table["composer_default_alert"],
          path: "builtins.calendar.month.popup.composer.default_alert"
        ) ?? fallback.composerDefaultAlert,
        defaultTravelTime: try optionalString(
          composerTable["default_travel_time"] ?? table["composer_default_travel_time"],
          path: "builtins.calendar.month.popup.composer.default_travel_time"
        ) ?? fallback.composerDefaultTravelTime,
        startLabel: try optionalString(
          composerTable["start_label"] ?? table["composer_start_label"],
          path: "builtins.calendar.month.popup.composer.start_label"
        ) ?? fallback.composerStartLabel,
        endLabel: try optionalString(
          composerTable["end_label"] ?? table["composer_end_label"],
          path: "builtins.calendar.month.popup.composer.end_label"
        ) ?? fallback.composerEndLabel,
        allDayLabel: try optionalString(
          composerTable["all_day_label"] ?? table["composer_all_day_label"],
          path: "builtins.calendar.month.popup.composer.all_day_label"
        ) ?? fallback.composerAllDayLabel,
        travelTimeLabel: try optionalString(
          composerTable["travel_time_label"] ?? table["composer_travel_time_label"],
          path: "builtins.calendar.month.popup.composer.travel_time_label"
        ) ?? fallback.composerTravelTimeLabel,
        alertLabel: try optionalString(
          composerTable["alert_label"] ?? table["composer_alert_label"],
          path: "builtins.calendar.month.popup.composer.alert_label"
        ) ?? fallback.composerAlertLabel,
        addAlertLabel: try optionalString(
          composerTable["add_alert_label"] ?? table["composer_add_alert_label"],
          path: "builtins.calendar.month.popup.composer.add_alert_label"
        ) ?? fallback.composerAddAlertLabel,
        openCalendarLabel: try optionalString(
          composerTable["open_calendar_label"] ?? table["composer_open_calendar_label"],
          path: "builtins.calendar.month.popup.composer.open_calendar_label"
        ) ?? fallback.composerOpenCalendarLabel,
        cancelLabel: try optionalString(
          composerTable["cancel_label"] ?? table["composer_cancel_label"],
          path: "builtins.calendar.month.popup.composer.cancel_label"
        ) ?? fallback.composerCancelLabel,
        saveLabel: try optionalString(
          composerTable["save_label"] ?? table["composer_save_label"],
          path: "builtins.calendar.month.popup.composer.save_label"
        ) ?? fallback.composerSaveLabel,
        updateLabel: try optionalString(
          composerTable["update_label"] ?? table["composer_update_label"],
          path: "builtins.calendar.month.popup.composer.update_label"
        ) ?? fallback.composerUpdateLabel,
        removeLabel: try optionalString(
          composerTable["remove_label"] ?? table["composer_remove_label"],
          path: "builtins.calendar.month.popup.composer.remove_label"
        ) ?? fallback.composerRemoveLabel,
        deleteConfirmationTitle: try optionalString(
          composerTable["delete_confirmation_title"] ?? table["composer_delete_confirmation_title"],
          path: "builtins.calendar.month.popup.composer.delete_confirmation_title"
        ) ?? fallback.composerDeleteConfirmationTitle,
        deleteConfirmationMessage: try optionalString(
          composerTable["delete_confirmation_message"] ?? table["composer_delete_confirmation_message"],
          path: "builtins.calendar.month.popup.composer.delete_confirmation_message"
        ) ?? fallback.composerDeleteConfirmationMessage
      ),
      todayButton: .init(
        title: try optionalString(
          todayButtonTable["title"] ?? table["today_button_title"],
          path: "builtins.calendar.month.popup.today_button.title"
        ) ?? fallback.todayButtonTitle,
        borderColorHex: try optionalString(
          todayButtonTable["border_color"] ?? table["today_border_color"],
          path: "builtins.calendar.month.popup.today_button.border_color"
        ) ?? fallback.todayButtonBorderColorHex,
        borderWidth: try optionalNumber(
          todayButtonTable["border_width"] ?? table["today_border_width"],
          path: "builtins.calendar.month.popup.today_button.border_width"
        ) ?? fallback.todayButtonBorderWidth
      )
    )
  }

  /// Validates the configured localized weekday format.
  func validatedMonthWeekdayFormat(
    _ value: String,
    path: String
  ) throws -> String {
    switch value {
    case "d", "dd", "ddd":
      return value
    case "dddd":
      throw ConfigError.invalidValue(
        path: path,
        message:
          "dddd is not allowed because full weekday names are too wide; use d, dd, ddd, or weekday_symbols"
      )
    default:
      throw ConfigError.invalidValue(
        path: path,
        message: "expected one of d, dd, or ddd"
      )
    }
  }

  /// Validates the optional manual weekday labels in Monday-to-Sunday order.
  func validatedMonthWeekdaySymbols(
    _ value: [String]?,
    path: String
  ) throws -> [String]? {
    guard let value else { return nil }

    guard value.count == 7 else {
      throw ConfigError.invalidValue(
        path: path,
        message: "expected exactly 7 weekday symbols ordered Monday through Sunday"
      )
    }

    let trimmed = value.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    guard trimmed.allSatisfy({ !$0.isEmpty }) else {
      throw ConfigError.invalidValue(
        path: path,
        message: "weekday symbols must not be empty"
      )
    }

    return trimmed
  }

  /// Resolves final localized weekday labels in Monday-to-Sunday order.
  static func resolveMonthWeekdaySymbols(
    format: String,
    manualSymbols: [String]?
  ) -> [String] {
    if let manualSymbols {
      return manualSymbols
    }

    let formatter = DateFormatter()

    let sundayFirstSymbols: [String]
    switch format {
    case "d":
      sundayFirstSymbols =
        formatter.veryShortStandaloneWeekdaySymbols
        ?? formatter.veryShortWeekdaySymbols
        ?? ["S", "M", "T", "W", "T", "F", "S"]

    case "dd":
      let baseSymbols =
        formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
      sundayFirstSymbols = baseSymbols.map { String($0.prefix(2)) }

    case "ddd":
      sundayFirstSymbols =
        formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    default:
      sundayFirstSymbols =
        formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }

    return normalizeSundayFirstWeekdaySymbolsToMondayFirst(sundayFirstSymbols)
  }

  /// Converts Sunday-first weekday symbols into Monday-first order.
  private static func normalizeSundayFirstWeekdaySymbolsToMondayFirst(_ symbols: [String])
    -> [String]
  {
    guard symbols.count == 7 else {
      return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }

    return Array(symbols[1...6]) + [symbols[0]]
  }
}
