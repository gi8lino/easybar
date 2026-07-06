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
        path: "builtins.calendar.month.popup.agenda.appointments_min_height",
        fallback: fallback.appointmentsMinHeight
      )

    let parsedMaxHeight =
      try optionalNumber(
        agendaTable["appointments_max_height"] ?? rootTable["appointments_max_height"],
        path: "builtins.calendar.month.popup.agenda.appointments_max_height",
        fallback: fallback.appointmentsMaxHeight
      )

    let minHeight = max(0, min(parsedMinHeight, parsedMaxHeight))
    let maxHeight = max(parsedMinHeight, parsedMaxHeight)

    return CalendarBuiltinConfig.Month.Popup.AgendaStyle(
      layout: try parseMonthCalendarPopupLayout(
        try optionalString(
          agendaTable["layout"] ?? rootTable["layout"],
          path: "builtins.calendar.month.popup.agenda.layout",
          fallback: fallback.layout.rawValue
        ),
        path: "builtins.calendar.month.popup.agenda.layout"
      ),
      appointmentsScrollable: try optionalBool(
        agendaTable["appointments_scrollable"] ?? rootTable["appointments_scrollable"],
        path: "builtins.calendar.month.popup.agenda.appointments_scrollable",
        fallback: fallback.appointmentsScrollable
      ),
      appointmentsMinHeight: minHeight,
      appointmentsMaxHeight: maxHeight,
      agendaTitle: try optionalString(
        agendaTable["agenda_title"] ?? rootTable["agenda_title"],
        path: "builtins.calendar.month.popup.agenda.agenda_title",
        fallback: fallback.agendaTitle
      ),
      maxVisibleAppointments: max(
        1,
        try optionalInt(
          agendaTable["max_visible_appointments"] ?? rootTable["max_visible_appointments"],
          path: "builtins.calendar.month.popup.agenda.max_visible_appointments",
          fallback: fallback.maxVisibleAppointments
        )
      )
    )
  }
}
