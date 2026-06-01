import EasyBarShared
import Foundation
import TOMLKit

extension CalendarBuiltinConfigParser {
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
}
