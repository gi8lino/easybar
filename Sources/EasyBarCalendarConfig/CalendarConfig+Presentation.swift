import EasyBarCalendarPresentation
import Foundation

extension CalendarBuiltinConfig {
  public var presentationFilters: CalendarRequestFilters {
    CalendarRequestFilters(
      includedCalendarNames: filters.includedCalendarNames,
      excludedCalendarNames: filters.excludedCalendarNames
    )
  }

  public var presentationBirthdays: CalendarBirthdayRequestOptions {
    CalendarBirthdayRequestOptions(
      showBirthdays: birthdays.showBirthdays,
      showAge: birthdays.birthdaysShowAge
    )
  }

  public var presentationUpcomingRequestOptions: CalendarUpcomingRequestOptions {
    CalendarUpcomingRequestOptions(
      dayCount: upcoming.events.days,
      emptyText: appointments.emptyText,
      birthdays: presentationBirthdays,
      filters: presentationFilters
    )
  }

  public var presentationMonthRequestOptions: CalendarMonthRequestOptions {
    CalendarMonthRequestOptions(
      emptyText: appointments.emptyText,
      birthdays: presentationBirthdays,
      filters: presentationFilters
    )
  }
}
