import EasyBarCalendarPresentation
import Foundation

public extension CalendarBuiltinConfig {
  var presentationFilters: CalendarRequestFilters {
    CalendarRequestFilters(
      includedCalendarNames: filters.includedCalendarNames,
      excludedCalendarNames: filters.excludedCalendarNames
    )
  }

  var presentationBirthdays: CalendarBirthdayRequestOptions {
    CalendarBirthdayRequestOptions(
      showBirthdays: birthdays.showBirthdays,
      showAge: birthdays.birthdaysShowAge
    )
  }

  var presentationUpcomingRequestOptions: CalendarUpcomingRequestOptions {
    CalendarUpcomingRequestOptions(
      dayCount: upcoming.events.days,
      emptyText: appointments.emptyText,
      birthdays: presentationBirthdays,
      filters: presentationFilters
    )
  }

  var presentationMonthRequestOptions: CalendarMonthRequestOptions {
    CalendarMonthRequestOptions(
      emptyText: appointments.emptyText,
      birthdays: presentationBirthdays,
      filters: presentationFilters
    )
  }
}
