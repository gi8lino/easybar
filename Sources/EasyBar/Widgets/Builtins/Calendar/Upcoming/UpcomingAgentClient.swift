import EasyBarShared
import Foundation

@MainActor
final class UpcomingCalendarAgentClient {

  static let shared = UpcomingCalendarAgentClient()

  private lazy var stream: CalendarAgentStreamController = CalendarAgentStreamController(
    label: "upcoming calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    makeRequest: { [weak self] in
      self?.makeRequest() ?? CalendarAgentRequest(command: .ping)
    },
    applySnapshot: { snapshot in
      NativeUpcomingCalendarStore.shared.apply(snapshot: snapshot)
    },
    clearState: {
      NativeUpcomingCalendarStore.shared.clear()
    }
  )

  private init() {}

  /// Returns whether the upcoming-calendar agent client is currently active.
  var isConnected: Bool {
    stream.isConnected
  }

  /// Starts the upcoming-calendar agent socket client when enabled.
  func start() {
    stream.start(enabled: Config.shared.calendarAgentEnabled)
  }

  /// Stops the upcoming-calendar agent socket client.
  func stop() {
    stream.stop()
  }

  /// Requests one fresh snapshot from the calendar agent.
  func refresh() {
    stream.refresh()
  }

  /// Builds the current upcoming-calendar request.
  private func makeRequest() -> CalendarAgentRequest {
    let now = Date()
    let calendarConfig = Config.shared.builtinCalendar
    let upcoming = calendarConfig.upcoming
    let requestedRange = CalendarNativeWidget.requestedDateRange(
      config: calendarConfig,
      now: now
    )

    easybarLog.debug(
      "requesting upcoming calendar snapshot start=\(requestedRange.start.timeIntervalSince1970) end=\(requestedRange.end.timeIntervalSince1970) days=\(upcoming.events.days) show_birthdays=\(upcoming.birthdays.show)"
    )

    let query = CalendarAgentQuery(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: now,
      sectionDayCount: upcoming.events.days,
      showBirthdays: upcoming.birthdays.show,
      emptyText: upcoming.events.emptyText,
      birthdaysTitle: upcoming.birthdays.title,
      birthdaysDateFormat: upcoming.birthdays.dateFormat,
      birthdaysShowAge: upcoming.birthdays.showAge,
      includedCalendarNames: [],
      excludedCalendarNames: []
    )

    return CalendarAgentRequest(
      command: .subscribe,
      query: query
    )
  }
}
