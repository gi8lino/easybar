import Foundation

extension Config.CalendarBuiltinConfig.Month.Popup {

  struct AgendaStyle {
    var layout: Config.MonthCalendarPopupLayout
    var appointmentsScrollable: Bool
    var appointmentsMinHeight: Double
    var appointmentsMaxHeight: Double
    var agendaTitle: String
    var maxVisibleAppointments: Int
  }
}
