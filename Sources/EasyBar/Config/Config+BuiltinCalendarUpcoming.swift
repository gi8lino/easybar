import Foundation
import TOMLKit

extension Config {

  /// Parses the upcoming calendar mode.
  func parseCalendarUpcoming(
    eventsTable: TOMLTable,
    birthdaysTable: TOMLTable,
    popupTable: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming
  ) throws -> CalendarBuiltinConfig.Upcoming {
    CalendarBuiltinConfig.Upcoming(
      events: try parseCalendarUpcomingEvents(
        from: eventsTable,
        fallback: fallback.events
      ),
      birthdays: try parseCalendarUpcomingBirthdays(
        from: birthdaysTable,
        fallback: fallback.birthdays
      ),
      popup: try parseCalendarUpcomingPopup(
        from: popupTable,
        fallback: fallback.popup
      )
    )
  }

  /// Parses the upcoming events block.
  func parseCalendarUpcomingEvents(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Events
  ) throws -> CalendarBuiltinConfig.Upcoming.Events {
    CalendarBuiltinConfig.Upcoming.Events(
      days: max(
        1,
        try optionalInt(
          table["days"],
          path: "builtins.calendar.upcoming.events.days"
        ) ?? fallback.days
      ),
      emptyText: try optionalString(
        table["empty_text"],
        path: "builtins.calendar.upcoming.events.empty_text"
      ) ?? fallback.emptyText
    )
  }

  /// Parses the upcoming birthdays block.
  func parseCalendarUpcomingBirthdays(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Birthdays
  ) throws -> CalendarBuiltinConfig.Upcoming.Birthdays {
    CalendarBuiltinConfig.Upcoming.Birthdays(
      show: try optionalBool(
        table["show"],
        path: "builtins.calendar.upcoming.birthdays.show"
      ) ?? fallback.show,
      title: try optionalString(
        table["title"],
        path: "builtins.calendar.upcoming.birthdays.title"
      ) ?? fallback.title,
      dateFormat: try optionalString(
        table["date_format"],
        path: "builtins.calendar.upcoming.birthdays.date_format"
      ) ?? fallback.dateFormat,
      showAge: try optionalBool(
        table["show_age"],
        path: "builtins.calendar.upcoming.birthdays.show_age"
      ) ?? fallback.showAge
    )
  }

  /// Parses the upcoming popup block.
  func parseCalendarUpcomingPopup(
    from table: TOMLTable,
    fallback: CalendarBuiltinConfig.Upcoming.Popup
  ) throws -> CalendarBuiltinConfig.Upcoming.Popup {
    let birthdaysTable = table["birthdays"]?.table ?? TOMLTable()
    let todayTable = table["today"]?.table ?? TOMLTable()
    let tomorrowTable = table["tomorrow"]?.table ?? TOMLTable()
    let futureTable = table["future"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Upcoming.Popup(
      backgroundColorHex: try optionalString(
        table["background_color"],
        path: "builtins.calendar.upcoming.popup.background_color"
      ) ?? fallback.backgroundColorHex,
      borderColorHex: try optionalString(
        table["border_color"],
        path: "builtins.calendar.upcoming.popup.border_color"
      ) ?? fallback.borderColorHex,
      borderWidth: try optionalNumber(
        table["border_width"],
        path: "builtins.calendar.upcoming.popup.border_width"
      ) ?? fallback.borderWidth,
      cornerRadius: try optionalNumber(
        table["corner_radius"],
        path: "builtins.calendar.upcoming.popup.corner_radius"
      ) ?? fallback.cornerRadius,
      paddingX: try optionalNumber(
        table["padding_x"],
        path: "builtins.calendar.upcoming.popup.padding_x"
      ) ?? fallback.paddingX,
      paddingY: try optionalNumber(
        table["padding_y"],
        path: "builtins.calendar.upcoming.popup.padding_y"
      ) ?? fallback.paddingY,
      spacing: try optionalNumber(
        table["spacing"],
        path: "builtins.calendar.upcoming.popup.spacing"
      ) ?? fallback.spacing,
      itemIndent: try optionalNumber(
        table["item_indent"],
        path: "builtins.calendar.upcoming.popup.item_indent"
      ) ?? fallback.itemIndent,
      marginX: try optionalNumber(
        table["margin_x"],
        path: "builtins.calendar.upcoming.popup.margin_x"
      ) ?? fallback.marginX,
      marginY: try optionalNumber(
        table["margin_y"],
        path: "builtins.calendar.upcoming.popup.margin_y"
      ) ?? fallback.marginY,
      showCalendarName: try optionalBool(
        table["show_calendar_name"],
        path: "builtins.calendar.upcoming.popup.show_calendar_name"
      ) ?? fallback.showCalendarName,
      useCalendarColors: try optionalBool(
        table["use_calendar_colors"],
        path: "builtins.calendar.upcoming.popup.use_calendar_colors"
      ) ?? fallback.useCalendarColors,
      birthdays: try parseCalendarUpcomingPopupSectionStyle(
        from: birthdaysTable,
        path: "builtins.calendar.upcoming.popup.birthdays",
        fallback: fallback.birthdays
      ),
      today: try parseCalendarUpcomingPopupSectionStyle(
        from: todayTable,
        path: "builtins.calendar.upcoming.popup.today",
        fallback: fallback.today
      ),
      tomorrow: try parseCalendarUpcomingPopupSectionStyle(
        from: tomorrowTable,
        path: "builtins.calendar.upcoming.popup.tomorrow",
        fallback: fallback.tomorrow
      ),
      future: try parseCalendarUpcomingPopupSectionStyle(
        from: futureTable,
        path: "builtins.calendar.upcoming.popup.future",
        fallback: fallback.future
      )
    )
  }

  /// Parses one upcoming popup section style block.
  func parseCalendarUpcomingPopupSectionStyle(
    from table: TOMLTable,
    path: String,
    fallback: CalendarBuiltinConfig.Upcoming.PopupSectionStyle
  ) throws -> CalendarBuiltinConfig.Upcoming.PopupSectionStyle {
    CalendarBuiltinConfig.Upcoming.PopupSectionStyle(
      titleColorHex: try optionalString(
        table["title_color"],
        path: "\(path).title_color"
      ) ?? fallback.titleColorHex,
      itemColorHex: try optionalString(
        table["item_color"],
        path: "\(path).item_color"
      ) ?? fallback.itemColorHex,
      emptyColorHex: try optionalString(
        table["empty_color"],
        path: "\(path).empty_color"
      ) ?? fallback.emptyColorHex
    )
  }
}
