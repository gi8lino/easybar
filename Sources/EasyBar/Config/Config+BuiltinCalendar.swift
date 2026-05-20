import EasyBarCalendarConfig
import Foundation
import TOMLKit

extension Config {

  /// Parses the built-in calendar widget.
  func parseCalendarBuiltin(from builtins: TOMLTable) throws {
    guard let calendar = builtins["calendar"]?.table else { return }

    let placement = try parseBuiltinPlacement(
      from: calendar,
      path: "builtins.calendar",
      fallback: .init(builtinCalendar.placement)
    )

    let styleTable = calendar["style"]?.table ?? TOMLTable()
    let anchorTable = calendar["anchor"]?.table ?? TOMLTable()
    let filtersTable = calendar["filters"]?.table ?? TOMLTable()
    let appointmentsTable = calendar["appointments"]?.table ?? TOMLTable()
    let birthdaysTable = calendar["birthdays"]?.table ?? TOMLTable()
    let composerTable = calendar["composer"]?.table ?? TOMLTable()

    let upcomingTable = calendar["upcoming"]?.table ?? TOMLTable()
    let upcomingEventsTable = upcomingTable["events"]?.table ?? TOMLTable()
    let upcomingPopupTable = upcomingTable["popup"]?.table ?? TOMLTable()

    let monthTable = calendar["month"]?.table ?? TOMLTable()
    let monthPopupTable = monthTable["popup"]?.table ?? TOMLTable()

    let style = try parseBuiltinStyle(
      from: styleTable,
      path: "builtins.calendar.style",
      fallback: .init(builtinCalendar.style)
    )

    let popupMode = try parseCalendarPopupMode(
      try optionalString(
        calendar["popup_mode"],
        path: "builtins.calendar.popup_mode"
      ) ?? builtinCalendar.popupMode.rawValue,
      path: "builtins.calendar.popup_mode"
    )

    let anchor = try parseCalendarAnchor(
      from: anchorTable,
      fallback: builtinCalendar.anchor
    )

    let filters = try parseCalendarFilters(
      from: filtersTable,
      fallback: builtinCalendar.filters
    )

    let appointments = try parseCalendarAppointments(
      from: appointmentsTable,
      fallback: builtinCalendar.appointments
    )

    let birthdays = try parseCalendarBirthdays(
      from: birthdaysTable,
      fallback: builtinCalendar.birthdays
    )

    let composer = try parseCalendarComposer(
      from: composerTable,
      fallback: builtinCalendar.composer
    )

    let upcoming = try parseCalendarUpcoming(
      eventsTable: upcomingEventsTable,
      popupTable: upcomingPopupTable,
      fallback: builtinCalendar.upcoming
    )

    let month = try parseCalendarMonth(
      popupTable: monthPopupTable,
      fallback: builtinCalendar.month
    )

    builtinCalendar = CalendarBuiltinConfig(
      placement: .init(placement),
      style: .init(style),
      popupMode: popupMode,
      anchor: anchor,
      filters: filters,
      appointments: appointments,
      birthdays: birthdays,
      composer: composer,
      upcoming: upcoming,
      month: month
    )
  }

  /// Parses the shared built-in calendar filters block.
  func parseCalendarFilters(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Filters
  ) throws -> CalendarBuiltinConfig.Filters {
    CalendarBuiltinConfig.Filters(
      includedCalendarNames: try optionalStringArray(
        table["included_calendar_names"],
        path: "builtins.calendar.filters.included_calendar_names"
      ) ?? fallback.includedCalendarNames,
      excludedCalendarNames: try optionalStringArray(
        table["excluded_calendar_names"],
        path: "builtins.calendar.filters.excluded_calendar_names"
      ) ?? fallback.excludedCalendarNames
    )
  }

  /// Parses the shared built-in calendar appointment row settings.
  func parseCalendarAppointments(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Appointments
  ) throws -> CalendarBuiltinConfig.Appointments {
    CalendarBuiltinConfig.Appointments(
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.appointments.item_indent"
      ) ?? fallback.itemIndent,
      eventTextColorHex: try optionalString(
        table["event_text_color"],
        path: "builtins.calendar.appointments.event_text_color"
      ) ?? fallback.eventTextColorHex,
      emptyTextColorHex: try optionalString(
        table["empty_text_color"],
        path: "builtins.calendar.appointments.empty_text_color"
      ) ?? fallback.emptyTextColorHex,
      secondaryTextColorHex: try optionalString(
        table["secondary_text_color"],
        path: "builtins.calendar.appointments.secondary_text_color"
      ) ?? fallback.secondaryTextColorHex,
      travelTextColorHex: try optionalString(
        table["travel_text_color"],
        path: "builtins.calendar.appointments.travel_text_color"
      ) ?? fallback.travelTextColorHex,
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.appointments.empty_text"
      ) ?? fallback.emptyText,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.appointments.show_calendar_name"
      ) ?? fallback.showCalendarName,
      showAllDayLabel: try optionalBool(
        table["show_all_day_label"],
        path: "builtins.calendar.appointments.show_all_day_label"
      ) ?? fallback.showAllDayLabel,
      showHolidayAllDayLabel: try optionalBool(
        table["show_holiday_all_day_label"],
        path: "builtins.calendar.appointments.show_holiday_all_day_label"
      ) ?? fallback.showHolidayAllDayLabel,
      allDayLabel: try optionalString(
        table["all_day_label"],
        path: "builtins.calendar.appointments.all_day_label"
      ) ?? fallback.allDayLabel,
      showLocation: try optionalBool(
        table["show_location"],
        path: "builtins.calendar.appointments.show_location"
      ) ?? fallback.showLocation,
      showTravelTime: try optionalBool(
        table["show_travel_time"],
        path: "builtins.calendar.appointments.show_travel_time"
      ) ?? fallback.showTravelTime,
      showEndTime: try optionalBool(
        table["show_end_time"],
        path: "builtins.calendar.appointments.show_end_time"
      ) ?? fallback.showEndTime,
      travelIcon: try optionalString(
        table["travel_icon"],
        path: "builtins.calendar.appointments.travel_icon"
      ) ?? fallback.travelIcon,
      travelIconColorHex: try optionalString(
        table["travel_icon_color"],
        path: "builtins.calendar.appointments.travel_icon_color"
      ) ?? fallback.travelIconColorHex,
      showAlertIcon: try optionalBool(
        table["show_alert_icon"],
        path: "builtins.calendar.appointments.show_alert_icon"
      ) ?? fallback.showAlertIcon,
      alertIcon: try optionalString(
        table["alert_icon"],
        path: "builtins.calendar.appointments.alert_icon"
      ) ?? fallback.alertIcon,
      alertIconColorHex: try optionalString(
        table["alert_icon_color"],
        path: "builtins.calendar.appointments.alert_icon_color"
      ) ?? fallback.alertIconColorHex
    )
  }

  /// Parses the shared built-in calendar birthday settings.
  func parseCalendarBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Birthdays
  ) throws -> CalendarBuiltinConfig.Birthdays {
    CalendarBuiltinConfig.Birthdays(
      showBirthdays: try optionalBool(
        table["show_birthdays"],
        path: "builtins.calendar.birthdays.show_birthdays"
      ) ?? fallback.showBirthdays,
      birthdaysShowAge: try optionalBool(
        table["birthdays_show_age"],
        path: "builtins.calendar.birthdays.birthdays_show_age"
      ) ?? fallback.birthdaysShowAge,
      birthdayIcon: try optionalString(
        table["birthday_icon"],
        path: "builtins.calendar.birthdays.birthday_icon"
      ) ?? fallback.birthdayIcon,
      birthdayIconColorHex: try optionalString(
        table["birthday_icon_color"],
        path: "builtins.calendar.birthdays.birthday_icon_color"
      ) ?? fallback.birthdayIconColorHex
    )
  }
}
