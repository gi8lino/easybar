import Foundation

extension Config.CalendarBuiltinConfig.Month.Popup {

  struct AgendaStyle {
    var eventTextColorHex: String
    var emptyTextColorHex: String
    var secondaryTextColorHex: String
    var travelTextColorHex: String
    var layout: Config.MonthCalendarPopupLayout
    var appointmentsScrollable: Bool
    var appointmentsMinHeight: Double
    var appointmentsMaxHeight: Double
    var emptyText: String
    var agendaTitle: String
    var showCalendarName: Bool
    var showAllDayLabel: Bool
    var showHolidayAllDayLabel: Bool
    var allDayLabel: String
    var showLocation: Bool
    var showTravelTime: Bool
    var travelIcon: String
    var travelIconColorHex: String?
    var showAlertIcon: Bool
    var alertIcon: String
    var alertIconColorHex: String?
    var maxVisibleAppointments: Int
  }

  struct BirthdaysStyle {
    var showBirthdays: Bool
    var birthdaysShowAge: Bool
    var birthdayIcon: String
    var birthdayIconColorHex: String?
  }

  struct Filters {
    var includedCalendarNames: [String]
    var excludedCalendarNames: [String]
  }
}
