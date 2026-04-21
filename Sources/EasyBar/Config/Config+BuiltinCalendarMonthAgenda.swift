import Foundation
import TOMLKit

extension Config {

  /// Parses the month popup agenda block.
  func parseCalendarMonthPopupAgenda(
    from agendaTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.AgendaStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.AgendaStyle {
    let parsedMinHeight =
      try optionalNumber(
        agendaTable["appointments_min_height"] ?? rootTable["appointments_min_height"],
        path: "builtins.calendar.month.popup.agenda.appointments_min_height"
      ) ?? fallback.appointmentsMinHeight

    let parsedMaxHeight =
      try optionalNumber(
        agendaTable["appointments_max_height"] ?? rootTable["appointments_max_height"],
        path: "builtins.calendar.month.popup.agenda.appointments_max_height"
      ) ?? fallback.appointmentsMaxHeight

    let minHeight = max(0, min(parsedMinHeight, parsedMaxHeight))
    let maxHeight = max(parsedMinHeight, parsedMaxHeight)

    return CalendarBuiltinConfig.Month.Popup.AgendaStyle(
      eventTextColorHex: try optionalString(
        agendaTable["event_text_color"] ?? rootTable["event_text_color"],
        path: "builtins.calendar.month.popup.agenda.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        agendaTable["empty_text_color"] ?? rootTable["empty_text_color"],
        path: "builtins.calendar.month.popup.agenda.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        agendaTable["secondary_text_color"] ?? rootTable["secondary_text_color"],
        path: "builtins.calendar.month.popup.agenda.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      travelTextColorHex: try optionalString(
        agendaTable["travel_text_color"] ?? rootTable["travel_text_color"],
        path: "builtins.calendar.month.popup.agenda.travel_text_color"
      ) ?? fallback.travelTextColorHex,
      layout: try parseMonthCalendarPopupLayout(
        try optionalString(
          agendaTable["layout"] ?? rootTable["layout"],
          path: "builtins.calendar.month.popup.agenda.layout"
        ) ?? fallback.layout.rawValue,
        path: "builtins.calendar.month.popup.agenda.layout"
      ),
      appointmentsScrollable: try optionalBool(
        agendaTable["appointments_scrollable"] ?? rootTable["appointments_scrollable"],
        path: "builtins.calendar.month.popup.agenda.appointments_scrollable"
      ) ?? fallback.appointmentsScrollable,
      appointmentsMinHeight: minHeight,
      appointmentsMaxHeight: maxHeight,
      emptyText: try optionalString(
        agendaTable["empty_text"] ?? rootTable["empty_text"],
        path: "builtins.calendar.month.popup.agenda.empty_text"
      ) ?? fallback.emptyText,
      agendaTitle: try optionalString(
        agendaTable["agenda_title"] ?? rootTable["agenda_title"],
        path: "builtins.calendar.month.popup.agenda.agenda_title"
      ) ?? fallback.agendaTitle,
      showCalendarName: try optionalBool(
        agendaTable["show_calendar_name"] ?? rootTable["show_calendar_name"],
        path: "builtins.calendar.month.popup.agenda.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        agendaTable["show_all_day_label"] ?? rootTable["show_all_day_label"],
        path: "builtins.calendar.month.popup.agenda.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      showHolidayAllDayLabel: try optionalBool(
        agendaTable["show_holiday_all_day_label"] ?? rootTable["show_holiday_all_day_label"],
        path: "builtins.calendar.month.popup.agenda.show_holiday_all_day_label"
      ) ?? fallback.showHolidayAllDayLabel,
      allDayLabel: try optionalString(
        agendaTable["all_day_label"] ?? rootTable["all_day_label"],
        path: "builtins.calendar.month.popup.agenda.all_day_label"
      ) ?? fallback.allDayLabel,
      showLocation: try optionalBool(
        agendaTable["show_location"] ?? rootTable["show_location"],
        path: "builtins.calendar.month.popup.agenda.show_location"
      ) ?? fallback.showLocation,
      showTravelTime: try optionalBool(
        agendaTable["show_travel_time"] ?? rootTable["show_travel_time"],
        path: "builtins.calendar.month.popup.agenda.show_travel_time"
      ) ?? fallback.showTravelTime,
      travelIcon: try optionalString(
        agendaTable["travel_icon"] ?? rootTable["travel_icon"],
        path: "builtins.calendar.month.popup.agenda.travel_icon"
      ) ?? fallback.travelIcon,
      travelIconColorHex: try optionalString(
        agendaTable["travel_icon_color"] ?? rootTable["travel_icon_color"],
        path: "builtins.calendar.month.popup.agenda.travel_icon_color"
      ) ?? fallback.travelIconColorHex,
      showAlertIcon: try optionalBool(
        agendaTable["show_alert_icon"] ?? rootTable["show_alert_icon"],
        path: "builtins.calendar.month.popup.agenda.show_alert_icon"
      ) ?? fallback.showAlertIcon,
      alertIcon: try optionalString(
        agendaTable["alert_icon"] ?? rootTable["alert_icon"],
        path: "builtins.calendar.month.popup.agenda.alert_icon"
      ) ?? fallback.alertIcon,
      alertIconColorHex: try optionalString(
        agendaTable["alert_icon_color"] ?? rootTable["alert_icon_color"],
        path: "builtins.calendar.month.popup.agenda.alert_icon_color"
      ) ?? fallback.alertIconColorHex,
      maxVisibleAppointments: max(
        1,
        try optionalInt(
          agendaTable["max_visible_appointments"] ?? rootTable["max_visible_appointments"],
          path: "builtins.calendar.month.popup.agenda.max_visible_appointments"
        ) ?? fallback.maxVisibleAppointments
      )
    )
  }

  /// Parses the month popup birthdays block.
  func parseCalendarMonthPopupBirthdays(
    from birthdaysTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.BirthdaysStyle
  ) throws -> CalendarBuiltinConfig.Month.Popup.BirthdaysStyle {
    CalendarBuiltinConfig.Month.Popup.BirthdaysStyle(
      showBirthdays: try optionalBool(
        birthdaysTable["show_birthdays"] ?? rootTable["show_birthdays"],
        path: "builtins.calendar.month.popup.birthdays.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        birthdaysTable["birthdays_show_age"] ?? rootTable["birthdays_show_age"],
        path: "builtins.calendar.month.popup.birthdays.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        birthdaysTable["birthday_icon"] ?? rootTable["birthday_icon"],
        path: "builtins.calendar.month.popup.birthdays.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        birthdaysTable["birthday_icon_color"] ?? rootTable["birthday_icon_color"],
        path: "builtins.calendar.month.popup.birthdays.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex
    )
  }

  /// Parses the month popup calendar filters block.
  func parseCalendarMonthPopupFilters(
    from filtersTable: TOMLTable,
    rootTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Month.Popup.Filters
  ) throws -> CalendarBuiltinConfig.Month.Popup.Filters {
    CalendarBuiltinConfig.Month.Popup.Filters(
      includedCalendarNames: try optionalStringArray(
        filtersTable["included_calendar_names"] ?? rootTable["included_calendar_names"],
        path: "builtins.calendar.month.popup.filters.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        filtersTable["excluded_calendar_names"] ?? rootTable["excluded_calendar_names"],
        path: "builtins.calendar.month.popup.filters.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames
    )
  }
}
