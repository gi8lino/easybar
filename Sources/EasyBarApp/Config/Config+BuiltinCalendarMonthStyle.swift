import Foundation
import TOMLKit

extension Config {

  /// Parses the shared month popup style block.
  func parseCalendarMonthPopupStyle(
    from styleTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.Style
  ) throws -> CalendarBuiltinConfig.Month.Popup.Style {
    CalendarBuiltinConfig.Month.Popup.Style(
      backgroundColorHex: try optionalString(
        styleTable["background_color"] ?? rootTable["background_color"],
        path: "builtins.calendar.month.popup.style.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        styleTable["border_color"] ?? rootTable["border_color"],
        path: "builtins.calendar.month.popup.style.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        styleTable["border_width"] ?? rootTable["border_width"],
        path: "builtins.calendar.month.popup.style.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        styleTable["corner_radius"] ?? rootTable["corner_radius"],
        path: "builtins.calendar.month.popup.style.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        styleTable["padding_x"] ?? rootTable["padding_x"],
        path: "builtins.calendar.month.popup.style.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        styleTable["padding_y"] ?? rootTable["padding_y"],
        path: "builtins.calendar.month.popup.style.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        styleTable["spacing"] ?? rootTable["spacing"],
        path: "builtins.calendar.month.popup.style.spacing"
      ) ?? fallback.spacing,
      marginX: try optionalNumber(
        styleTable["margin_x"] ?? rootTable["margin_x"],
        path: "builtins.calendar.month.popup.style.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        styleTable["margin_y"] ?? rootTable["margin_y"],
        path: "builtins.calendar.month.popup.style.margin_y"
      ) ?? fallback.marginY
    )
  }

  /// Parses the month popup calendar grid block.
  func parseCalendarMonthPopupCalendar(
    from calendarTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.CalendarStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.CalendarStyle {
    let weekdayFormat = try validatedMonthWeekdayFormat(
      try optionalString(
        calendarTable["weekday_format"] ?? rootTable["weekday_format"],
        path: "builtins.calendar.month.popup.calendar.weekday_format"
      ) ?? fallback.weekdayFormat,
      path: "builtins.calendar.month.popup.calendar.weekday_format"
    )

    let weekdaySymbols = try validatedMonthWeekdaySymbols(
      try optionalStringArray(
        calendarTable["weekday_symbols"] ?? rootTable["weekday_symbols"],
        path: "builtins.calendar.month.popup.calendar.weekday_symbols"
      ) ?? fallback.weekdaySymbols,
      path: "builtins.calendar.month.popup.calendar.weekday_symbols"
    )

    let parsedFirstWeekday =
      try optionalInt(
        calendarTable["first_weekday"] ?? rootTable["first_weekday"],
        path: "builtins.calendar.month.popup.calendar.first_weekday"
      ) ?? fallback.firstWeekday

    if let parsedFirstWeekday, !(1...7).contains(parsedFirstWeekday) {
      throw ConfigError.invalidValue(
        path: "builtins.calendar.month.popup.calendar.first_weekday",
        message: "expected integer from 1 to 7"
      )
    }

    let resolvedWeekdaySymbols = CalendarBuiltinConfig.resolveMonthWeekdaySymbols(
      format: weekdayFormat,
      manualSymbols: weekdaySymbols
    )

    return CalendarBuiltinConfig.Month.Popup.CalendarStyle(
      showWeekNumbers: try optionalBool(
        calendarTable["show_week_numbers"] ?? rootTable["show_week_numbers"],
        path: "builtins.calendar.month.popup.calendar.show_week_numbers"
      ) ?? fallback.showWeekNumbers,
      showEventIndicators: try optionalBool(
        calendarTable["show_event_indicators"] ?? rootTable["show_event_indicators"],
        path: "builtins.calendar.month.popup.calendar.show_event_indicators"
      ) ?? fallback.showEventIndicators,
      headerTextColorHex: try optionalString(
        calendarTable["header_text_color"] ?? rootTable["header_text_color"],
        path: "builtins.calendar.month.popup.calendar.header_text_color"
      ) ?? fallback.headerTextColorHex,
      weekdayTextColorHex: try optionalString(
        calendarTable["weekday_text_color"] ?? rootTable["weekday_text_color"],
        path: "builtins.calendar.month.popup.calendar.weekday_text_color"
      ) ?? fallback.weekdayTextColorHex,
      firstWeekday: parsedFirstWeekday,
      weekdayFormat: weekdayFormat,
      weekdaySymbols: weekdaySymbols,
      resolvedWeekdaySymbols: resolvedWeekdaySymbols,
      dayTextColorHex: try optionalString(
        calendarTable["day_text_color"] ?? rootTable["day_text_color"],
        path: "builtins.calendar.month.popup.calendar.day_text_color"
      ) ?? fallback.dayTextColorHex,
      outsideMonthTextColorHex: try optionalString(
        calendarTable["outside_month_text_color"] ?? rootTable["outside_month_text_color"],
        path: "builtins.calendar.month.popup.calendar.outside_month_text_color"
      ) ?? fallback.outsideMonthTextColorHex,
      todayCellBackgroundColorHex: try optionalString(
        calendarTable["today_cell_background_color"] ?? rootTable["today_cell_background_color"],
        path: "builtins.calendar.month.popup.calendar.today_cell_background_color"
      ) ?? fallback.todayCellBackgroundColorHex,
      todayCellBorderColorHex: try optionalString(
        calendarTable["today_cell_border_color"] ?? rootTable["today_cell_border_color"],
        path: "builtins.calendar.month.popup.calendar.today_cell_border_color"
      ) ?? fallback.todayCellBorderColorHex,
      todayCellBorderWidth: try optionalNumber(
        calendarTable["today_cell_border_width"] ?? rootTable["today_cell_border_width"],
        path: "builtins.calendar.month.popup.calendar.today_cell_border_width"
      ) ?? fallback.todayCellBorderWidth,
      indicatorColorHex: try optionalString(
        calendarTable["indicator_color"] ?? rootTable["indicator_color"],
        path: "builtins.calendar.month.popup.calendar.indicator_color"
      ) ?? fallback.indicatorColorHex
    )
  }

  /// Parses the month popup selection block.
  func parseCalendarMonthPopupSelection(
    from selectionTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.SelectionStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.SelectionStyle {
    CalendarBuiltinConfig.Month.Popup.SelectionStyle(
      selectedTextColorHex: try optionalString(
        selectionTable["selected_text_color"] ?? rootTable["selected_text_color"],
        path: "builtins.calendar.month.popup.selection.selected_text_color"
      ) ?? fallback.selectedTextColorHex,
      selectedBackgroundColorHex: try optionalString(
        selectionTable["selected_background_color"] ?? rootTable["selected_background_color"],
        path: "builtins.calendar.month.popup.selection.selected_background_color"
      ) ?? fallback.selectedBackgroundColorHex,
      selectionDateFormat: try optionalString(
        selectionTable["selection_date_format"] ?? rootTable["selection_date_format"],
        path: "builtins.calendar.month.popup.selection.selection_date_format"
      ) ?? fallback.selectionDateFormat,
      selectionDateSeparator: try optionalString(
        selectionTable["selection_date_separator"] ?? rootTable["selection_date_separator"],
        path: "builtins.calendar.month.popup.selection.selection_date_separator"
      ) ?? fallback.selectionDateSeparator,
      allowsRangeSelection: try optionalBool(
        selectionTable["allows_range_selection"] ?? rootTable["allows_range_selection"],
        path: "builtins.calendar.month.popup.selection.allows_range_selection"
      ) ?? fallback.allowsRangeSelection,
      resetSelectionOnThirdTap: try optionalBool(
        selectionTable["reset_selection_on_third_tap"] ?? rootTable["reset_selection_on_third_tap"],
        path: "builtins.calendar.month.popup.selection.reset_selection_on_third_tap"
      ) ?? fallback.resetSelectionOnThirdTap
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
}
