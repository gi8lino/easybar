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
    let composerAlertLabelsTable = composerTable["alert_labels"]?.table ?? TOMLTable()
    let composerTravelTimeLabelsTable = composerTable["travel_time_labels"]?.table ?? TOMLTable()
    let todayButtonTable = table["today_button"]?.table ?? TOMLTable()

    return CalendarBuiltinConfig.Month.Popup(
      style: try parseCalendarMonthPopupStyle(
        from: styleTable,
        rootTable: table,
        fallback: fallback.style
      ),
      calendar: try parseCalendarMonthPopupCalendar(
        from: calendarTable,
        rootTable: table,
        fallback: fallback.calendar
      ),
      selection: try parseCalendarMonthPopupSelection(
        from: selectionTable,
        rootTable: table,
        fallback: fallback.selection
      ),
      agenda: try parseCalendarMonthPopupAgenda(
        from: agendaTable,
        rootTable: table,
        fallback: fallback.agenda
      ),
      birthdays: try parseCalendarMonthPopupBirthdays(
        from: birthdaysTable,
        rootTable: table,
        fallback: fallback.birthdays
      ),
      filters: try parseCalendarMonthPopupFilters(
        from: filtersTable,
        rootTable: table,
        fallback: fallback.filters
      ),
      anchor: try parseCalendarMonthPopupAnchor(
        from: anchorTable,
        rootTable: table,
        fallback: fallback.anchor
      ),
      composer: try parseCalendarMonthPopupComposer(
        from: composerTable,
        alertLabelsTable: composerAlertLabelsTable,
        travelTimeLabelsTable: composerTravelTimeLabelsTable,
        rootTable: table,
        fallback: fallback.composer
      ),
      todayButton: try parseCalendarMonthPopupTodayButton(
        from: todayButtonTable,
        rootTable: table,
        fallback: fallback.todayButton
      )
    )
  }
}
