import EasyBarShared
import Foundation

/// Outbound calendar-agent socket request envelope.
struct CalendarAgentRequestEnvelope: Encodable {
  let command: String
  let query: CalendarAgentQueryEnvelope?
}

/// Outbound calendar-agent query payload.
///
/// This mirrors the query shape consumed by the calendar agent server.
struct CalendarAgentQueryEnvelope: Encodable {
  let startDate: Date
  let endDate: Date
  let sectionStartDate: Date?
  let sectionDayCount: Int?
  let showBirthdays: Bool
  let birthdaysShowAge: Bool
  let birthdaysTitle: String
  let birthdaysDateFormat: String
  let includedCalendarNames: [String]
  let excludedCalendarNames: [String]
  let emptyText: String
}

/// Inbound calendar-agent socket response envelope.
struct CalendarAgentResponseEnvelope: Decodable {
  let kind: String
  let snapshot: CalendarAgentSnapshot?
  let message: String?
}

extension CalendarAgentRequestEnvelope {
  /// Builds one fetch request for the given query.
  static func fetch(query: CalendarAgentQueryEnvelope) -> CalendarAgentRequestEnvelope {
    CalendarAgentRequestEnvelope(
      command: "fetch",
      query: query
    )
  }
}

extension CalendarAgentQueryEnvelope {
  /// Builds the query used by the upcoming-calendar popup.
  static func upcoming(
    config: Config.CalendarBuiltinConfig,
    now: Date,
    requestedRange: DateInterval
  ) -> CalendarAgentQueryEnvelope {
    let upcoming = config.upcoming

    return CalendarAgentQueryEnvelope(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: Calendar.current.startOfDay(for: now),
      sectionDayCount: max(1, upcoming.events.days),
      showBirthdays: upcoming.birthdays.show,
      birthdaysShowAge: upcoming.birthdays.showAge,
      birthdaysTitle: upcoming.birthdays.title,
      birthdaysDateFormat: upcoming.birthdays.dateFormat,
      includedCalendarNames: [],
      excludedCalendarNames: [],
      emptyText: upcoming.events.emptyText
    )
  }

  /// Builds the query used by the month-calendar popup.
  static func month(
    config: Config.CalendarBuiltinConfig.Month.Popup,
    requestedRange: DateInterval
  ) -> CalendarAgentQueryEnvelope {
    CalendarAgentQueryEnvelope(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: nil,
      sectionDayCount: nil,
      showBirthdays: false,
      birthdaysShowAge: false,
      birthdaysTitle: "",
      birthdaysDateFormat: "",
      includedCalendarNames: config.includedCalendarNames,
      excludedCalendarNames: config.excludedCalendarNames,
      emptyText: config.emptyText
    )
  }
}
