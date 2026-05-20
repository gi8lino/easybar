import EasyBarShared
import Foundation

/// Calendar filters shared across calendar clients.
public struct CalendarRequestFilters: Equatable, Sendable {
  public let includedCalendarNames: [String]
  public let excludedCalendarNames: [String]

  public init(
    includedCalendarNames: [String] = [],
    excludedCalendarNames: [String] = []
  ) {
    self.includedCalendarNames = includedCalendarNames
    self.excludedCalendarNames = excludedCalendarNames
  }
}

/// Birthday-related request options shared across calendar clients.
public struct CalendarBirthdayRequestOptions: Equatable, Sendable {
  public let showBirthdays: Bool
  public let showAge: Bool

  public init(showBirthdays: Bool, showAge: Bool) {
    self.showBirthdays = showBirthdays
    self.showAge = showAge
  }
}

/// Options used to build one upcoming-calendar request.
public struct CalendarUpcomingRequestOptions: Equatable, Sendable {
  public let dayCount: Int
  public let emptyText: String
  public let birthdaysDateFormat: String
  public let birthdaysTitle: String
  public let birthdays: CalendarBirthdayRequestOptions
  public let filters: CalendarRequestFilters

  public init(
    dayCount: Int,
    emptyText: String,
    birthdaysDateFormat: String = "dd.MM.yyyy",
    birthdaysTitle: String = "",
    birthdays: CalendarBirthdayRequestOptions,
    filters: CalendarRequestFilters
  ) {
    self.dayCount = dayCount
    self.emptyText = emptyText
    self.birthdaysDateFormat = birthdaysDateFormat
    self.birthdaysTitle = birthdaysTitle
    self.birthdays = birthdays
    self.filters = filters
  }
}

/// Options used to build one month-calendar request.
public struct CalendarMonthRequestOptions: Equatable, Sendable {
  public let emptyText: String
  public let birthdaysDateFormat: String
  public let birthdaysTitle: String
  public let birthdays: CalendarBirthdayRequestOptions
  public let filters: CalendarRequestFilters

  public init(
    emptyText: String,
    birthdaysDateFormat: String = "dd.MM.yyyy",
    birthdaysTitle: String = "",
    birthdays: CalendarBirthdayRequestOptions,
    filters: CalendarRequestFilters
  ) {
    self.emptyText = emptyText
    self.birthdaysDateFormat = birthdaysDateFormat
    self.birthdaysTitle = birthdaysTitle
    self.birthdays = birthdays
    self.filters = filters
  }
}

/// Builds stable calendar-agent requests from reusable inputs.
public enum CalendarRequestFactory {
  /// Returns the fetch range required by the upcoming popup.
  public static func requestedUpcomingDateRange(
    now: Date,
    dayCount: Int,
    calendar: Calendar = .current
  ) -> DateInterval {
    let start = calendar.startOfDay(for: now)
    let normalizedDayCount = max(1, dayCount)
    let end =
      calendar.date(byAdding: .day, value: normalizedDayCount, to: start)
      ?? now.addingTimeInterval(TimeInterval(normalizedDayCount * 86_400))

    return DateInterval(start: start, end: end)
  }

  /// Builds one upcoming-calendar subscribe request.
  public static func makeUpcomingSubscribeRequest(
    now: Date,
    options: CalendarUpcomingRequestOptions,
    calendar: Calendar = .current
  ) -> CalendarAgentRequest {
    let requestedRange = requestedUpcomingDateRange(
      now: now,
      dayCount: options.dayCount,
      calendar: calendar
    )

    return CalendarAgentRequest(
      command: .subscribe,
      query: CalendarAgentQuery(
        startDate: requestedRange.start,
        endDate: requestedRange.end,
        sectionStartDate: nil,
        sectionDayCount: nil,
        showBirthdays: options.birthdays.showBirthdays,
        emptyText: options.emptyText,
        birthdaysTitle: options.birthdaysTitle,
        birthdaysDateFormat: options.birthdaysDateFormat,
        birthdaysShowAge: options.birthdays.showAge,
        includedCalendarNames: options.filters.includedCalendarNames,
        excludedCalendarNames: options.filters.excludedCalendarNames
      )
    )
  }

  /// Builds one month-calendar subscribe request for an already prepared date range.
  public static func makeMonthSubscribeRequest(
    range: DateInterval,
    options: CalendarMonthRequestOptions
  ) -> CalendarAgentRequest {
    CalendarAgentRequest(
      command: .subscribe,
      query: CalendarAgentQuery(
        startDate: range.start,
        endDate: range.end,
        sectionStartDate: nil,
        sectionDayCount: nil,
        showBirthdays: options.birthdays.showBirthdays,
        emptyText: options.emptyText,
        birthdaysTitle: options.birthdaysTitle,
        birthdaysDateFormat: options.birthdaysDateFormat,
        birthdaysShowAge: options.birthdays.showAge,
        includedCalendarNames: options.filters.includedCalendarNames,
        excludedCalendarNames: options.filters.excludedCalendarNames
      )
    )
  }
}
