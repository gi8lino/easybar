import EasyBarShared
import Foundation

final class MonthCalendarAgentClient {

  static let shared = MonthCalendarAgentClient()

  private lazy var stream = CalendarAgentStreamController(
    label: "month calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    makeRequest: { [weak self] in
      self?.makeRequest()
    },
    applySnapshot: { snapshot in
      NativeMonthCalendarStore.shared.apply(snapshot: snapshot)
    }
  )

  private init() {}

  /// Returns whether the month-calendar agent client is currently active.
  var isConnected: Bool {
    stream.isConnected
  }

  /// Starts the month-calendar agent socket client when enabled.
  func start() {
    stream.start(enabled: Config.shared.calendarAgentEnabled)
  }

  /// Stops the month-calendar agent socket client.
  func stop() {
    stream.stop()
  }

  /// Refreshes the active month subscription if the preload window changed.
  func refreshMonthSubscriptionIfNeeded(for visibleMonth: Date) {
    let changed = NativeMonthCalendarStore.shared.prepareMonthSubscriptionRange(for: visibleMonth)
    guard changed else { return }

    refresh()
  }

  /// Requests one fresh month-calendar snapshot.
  func refresh() {
    stream.refresh()
  }

  /// Builds the current month-calendar fetch request.
  private func makeRequest() -> CalendarAgentRequestEnvelope {
    let requestedRange: DateInterval

    if let prepared = NativeMonthCalendarStore.shared.monthSubscriptionRange() {
      requestedRange = DateInterval(start: prepared.start, end: prepared.end)
    } else {
      requestedRange = defaultRequestedDateRange(referenceDate: Date())
    }

    let calendarConfig = Config.shared.builtinCalendar
    let monthConfig = calendarConfig.month.popup
    let upcomingBirthdays = calendarConfig.upcoming.birthdays

    Logger.debug(
      "requesting month calendar snapshot start=\(requestedRange.start.timeIntervalSince1970) end=\(requestedRange.end.timeIntervalSince1970) show_birthdays=\(monthConfig.showBirthdays) birthdays_show_age=\(monthConfig.birthdaysShowAge)"
    )

    let query = CalendarAgentQueryEnvelope(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: nil,
      sectionDayCount: nil,
      showBirthdays: monthConfig.showBirthdays,
      birthdaysShowAge: monthConfig.birthdaysShowAge,
      birthdaysTitle: upcomingBirthdays.title,
      birthdaysDateFormat: upcomingBirthdays.dateFormat,
      includedCalendarNames: monthConfig.includedCalendarNames,
      excludedCalendarNames: monthConfig.excludedCalendarNames,
      emptyText: monthConfig.emptyText
    )

    return CalendarAgentRequestEnvelope(
      command: "fetch",
      query: query
    )
  }

  /// Returns the default month preload range around the given reference date.
  private func defaultRequestedDateRange(referenceDate: Date) -> DateInterval {
    let calendar = Calendar.current

    let currentMonthStart =
      calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))
      ?? calendar.startOfDay(for: referenceDate)

    let start =
      calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
      ?? currentMonthStart

    let end =
      calendar.date(byAdding: .month, value: 2, to: currentMonthStart)
      ?? referenceDate.addingTimeInterval(90 * 86_400)

    return DateInterval(start: start, end: end)
  }
}
