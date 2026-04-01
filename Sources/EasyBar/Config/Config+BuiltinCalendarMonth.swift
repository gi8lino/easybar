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
    let parsedMinHeight =
      try optionalNumber(
        table["appointments_min_height"],
        path: "builtins.calendar.month.popup.appointments_min_height"
      ) ?? fallback.appointmentsMinHeight

    let parsedMaxHeight =
      try optionalNumber(
        table["appointments_max_height"],
        path: "builtins.calendar.month.popup.appointments_max_height"
      ) ?? fallback.appointmentsMaxHeight

    let minHeight = max(0, min(parsedMinHeight, parsedMaxHeight))
    let maxHeight = max(parsedMinHeight, parsedMaxHeight)

    let weekdayFormat = try validatedMonthWeekdayFormat(
      try optionalString(
        table["weekday_format"],
        path: "builtins.calendar.month.popup.weekday_format"
      ) ?? fallback.weekdayFormat,
      path: "builtins.calendar.month.popup.weekday_format"
    )

    let weekdaySymbols = try validatedMonthWeekdaySymbols(
      try optionalStringArray(
        table["weekday_symbols"],
        path: "builtins.calendar.month.popup.weekday_symbols"
      ) ?? fallback.weekdaySymbols,
      path: "builtins.calendar.month.popup.weekday_symbols"
    )

    let parsedFirstWeekday =
      try optionalInt(
        table["first_weekday"],
        path: "builtins.calendar.month.popup.first_weekday"
      ) ?? fallback.firstWeekday

    if let parsedFirstWeekday, !(1...7).contains(parsedFirstWeekday) {
      throw ConfigError.invalidValue(
        path: "builtins.calendar.month.popup.first_weekday",
        message: "expected integer from 1 to 7"
      )
    }

    let resolvedWeekdaySymbols = Self.resolveMonthWeekdaySymbols(
      format: weekdayFormat,
      manualSymbols: weekdaySymbols
    )

    return CalendarBuiltinConfig.Month.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.month.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.month.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.month.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.month.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.month.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.month.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.calendar.month.popup.spacing"
      ) ?? fallback.spacing,
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.month.popup.item_indent"
      ) ?? fallback.itemIndent,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.calendar.month.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.calendar.month.popup.margin_y"
      ) ?? fallback.marginY,
      showWeekNumbers: try optionalBool(
        table["show_week_numbers"],
        path: "builtins.calendar.month.popup.show_week_numbers"
      ) ?? fallback.showWeekNumbers,
      showEventIndicators: try optionalBool(
        table["show_event_indicators"],
        path: "builtins.calendar.month.popup.show_event_indicators"
      ) ?? fallback.showEventIndicators,
      headerTextColorHex: try optionalString(
        table["header_text_color"],
        path: "builtins.calendar.month.popup.header_text_color"
      ) ?? fallback.headerTextColorHex,
      weekdayTextColorHex: try optionalString(
        table["weekday_text_color"],
        path: "builtins.calendar.month.popup.weekday_text_color"
      ) ?? fallback.weekdayTextColorHex,
      firstWeekday: parsedFirstWeekday,
      dayTextColorHex: try optionalString(
        table["day_text_color"],
        path: "builtins.calendar.month.popup.day_text_color"
      ) ?? fallback.dayTextColorHex,
      outsideMonthTextColorHex: try optionalString(
        table["outside_month_text_color"],
        path: "builtins.calendar.month.popup.outside_month_text_color"
      ) ?? fallback.outsideMonthTextColorHex,
      selectedTextColorHex: try optionalString(
        table["selected_text_color"],
        path: "builtins.calendar.month.popup.selected_text_color"
      ) ?? fallback.selectedTextColorHex,
      selectedBackgroundColorHex: try optionalString(
        table["selected_background_color"],
        path: "builtins.calendar.month.popup.selected_background_color"
      ) ?? fallback.selectedBackgroundColorHex,
      todayBackgroundColorHex: try optionalString(
        table["today_background_color"],
        path: "builtins.calendar.month.popup.today_background_color"
      ) ?? fallback.todayBackgroundColorHex,
      indicatorColorHex: try optionalString(
        table["indicator_color"],
        path: "builtins.calendar.month.popup.indicator_color"
      ) ?? fallback.indicatorColorHex,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "builtins.calendar.month.popup.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "builtins.calendar.month.popup.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "builtins.calendar.month.popup.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      layout: MonthCalendarPopupLayout(
        rawValue: try optionalString(
          table["layout"],
          path: "builtins.calendar.month.popup.layout"
        ) ?? fallback.layout.rawValue
      ) ?? fallback.layout,
      appointmentsScrollable: try optionalBool(
        table["appointments_scrollable"],
        path: "builtins.calendar.month.popup.appointments_scrollable"
      ) ?? fallback.appointmentsScrollable,
      appointmentsMinHeight: minHeight,
      appointmentsMaxHeight: maxHeight,
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.month.popup.empty_text"
      ) ?? fallback.emptyText,
      agendaTitle: try optionalString(
        table["agenda_title"],
        path: "builtins.calendar.month.popup.agenda_title"
      ) ?? fallback.agendaTitle,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.month.popup.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "builtins.calendar.month.popup.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      allowsRangeSelection: try optionalBool(
        table["allows_range_selection"],
        path: "builtins.calendar.month.popup.allows_range_selection"
      ) ?? fallback.allowsRangeSelection,
      resetSelectionOnThirdTap: try optionalBool(
        table["reset_selection_on_third_tap"],
        path: "builtins.calendar.month.popup.reset_selection_on_third_tap"
      ) ?? fallback.resetSelectionOnThirdTap,
      maxVisibleAppointments: max(
        1,
        try optionalInt(
          table["max_visible_appointments"],
          path: "builtins.calendar.month.popup.max_visible_appointments"
        ) ?? fallback.maxVisibleAppointments
      ),
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "builtins.calendar.month.popup.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "builtins.calendar.month.popup.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames,
      anchorDateFormat: try optionalString(
        table["anchor_date_format"],
        path: "builtins.calendar.month.popup.anchor_date_format"
      ) ?? fallback.anchorDateFormat,
      anchorTextColorHex: try optionalString(
        table["anchor_text_color"],
        path: "builtins.calendar.month.popup.anchor_text_color"
      ) ?? fallback.anchorTextColorHex,
      anchorShowDateText: try optionalBool(
        table["anchor_show_date_text"],
        path: "builtins.calendar.month.popup.anchor_show_date_text"
      ) ?? fallback.anchorShowDateText,
      weekdayFormat: weekdayFormat,
      weekdaySymbols: weekdaySymbols,
      resolvedWeekdaySymbols: resolvedWeekdaySymbols,
      showBirthdays: try optionalBool(
        table["show_birthdays"],
        path: "builtins.calendar.month.popup.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        table["birthdays_show_age"],
        path: "builtins.calendar.month.popup.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        table["birthday_icon"],
        path: "builtins.calendar.month.popup.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        table["birthday_icon_color"],
        path: "builtins.calendar.month.popup.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex,
      selectionDateFormat: try optionalString(
        table["selection_date_format"],
        path: "builtins.calendar.month.popup.selection_date_format"
      ) ?? fallback.selectionDateFormat,
      composerTitlePlaceholder: try optionalString(
        table["composer_title_placeholder"],
        path: "builtins.calendar.month.popup.composer_title_placeholder"
      ) ?? fallback.composerTitlePlaceholder,
      composerLocationPlaceholder: try optionalString(
        table["composer_location_placeholder"],
        path: "builtins.calendar.month.popup.composer_location_placeholder"
      ) ?? fallback.composerLocationPlaceholder,
      composerDefaultCalendarName: try optionalString(
        table["composer_default_calendar_name"],
        path: "builtins.calendar.month.popup.composer_default_calendar_name"
      ) ?? fallback.composerDefaultCalendarName,
      composerDefaultAlert: try optionalString(
        table["composer_default_alert"],
        path: "builtins.calendar.month.popup.composer_default_alert"
      ) ?? fallback.composerDefaultAlert,
      composerDefaultTravelTime: try optionalString(
        table["composer_default_travel_time"],
        path: "builtins.calendar.month.popup.composer_default_travel_time"
      ) ?? fallback.composerDefaultTravelTime
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
