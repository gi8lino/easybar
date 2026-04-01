import EasyBarShared
import Foundation

final class MonthCalendarAgentClient {

  static let shared = MonthCalendarAgentClient()

  private lazy var stream: CalendarAgentStreamController = CalendarAgentStreamController(
    label: "month calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    makeRequest: { [weak self] in
      self?.makeRequest() ?? CalendarAgentRequest(command: .ping)
    },
    applySnapshot: { snapshot in
      NativeMonthCalendarStore.shared.apply(snapshot: snapshot)
    },
    clearState: {
      NativeMonthCalendarStore.shared.clear()
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

  /// Sends one create-event request through the calendar agent.
  func createEvent(
    _ event: CalendarAgentCreateEvent,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    let request = CalendarAgentRequest(
      command: .createEvent,
      createEvent: event
    )

    sendOneShot(request: request, successKind: .created, completion: completion)
  }

  /// Sends one update-event request through the calendar agent.
  func updateEvent(
    _ event: CalendarAgentUpdateEvent,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    let request = CalendarAgentRequest(
      command: .updateEvent,
      updateEvent: event
    )

    sendOneShot(request: request, successKind: .updated, completion: completion)
  }

  /// Sends one delete-event request through the calendar agent.
  func deleteEvent(
    _ event: CalendarAgentDeleteEvent,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    let request = CalendarAgentRequest(
      command: .deleteEvent,
      deleteEvent: event
    )

    sendOneShot(request: request, successKind: .deleted, completion: completion)
  }

  /// Sends one mutating request through the calendar agent.
  private func sendOneShot(
    request: CalendarAgentRequest,
    successKind: CalendarAgentMessageKind,
    completion: @escaping (_ success: Bool, _ message: String?) -> Void
  ) {
    let socketPath = Config.shared.calendarAgentSocketPath

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let response = try CalendarAgentOneShotClient.send(
          request: request,
          socketPath: socketPath
        )

        DispatchQueue.main.async {
          switch response.kind {
          case successKind:
            self.refresh()
            UpcomingCalendarAgentClient.shared.refresh()
            completion(true, nil)

          case .error:
            let message = response.message ?? "unknown"
            Logger.error("month calendar mutation failed message=\(message)")
            completion(false, message)

          default:
            Logger.error(
              "month calendar mutation unexpected response=\(response.kind.rawValue)"
            )
            completion(false, "unexpected_response")
          }
        }
      } catch {
        DispatchQueue.main.async {
          Logger.error("month calendar mutation failed error=\(error)")
          completion(false, error.localizedDescription)
        }
      }
    }
  }

  /// Builds the current month-calendar fetch request.
  private func makeRequest() -> CalendarAgentRequest {
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

    let query = CalendarAgentQuery(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: nil,
      sectionDayCount: nil,
      showBirthdays: monthConfig.showBirthdays,
      emptyText: monthConfig.emptyText,
      birthdaysTitle: upcomingBirthdays.title,
      birthdaysDateFormat: upcomingBirthdays.dateFormat,
      birthdaysShowAge: monthConfig.birthdaysShowAge,
      includedCalendarNames: monthConfig.includedCalendarNames,
      excludedCalendarNames: monthConfig.excludedCalendarNames
    )

    return CalendarAgentRequest(
      command: .subscribe,
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
