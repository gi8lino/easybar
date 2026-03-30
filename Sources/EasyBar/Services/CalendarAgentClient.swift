import EasyBarShared
import Foundation

final class CalendarAgentClient {
  static let shared = CalendarAgentClient()

  private lazy var client = AgentSocketClient<CalendarAgentRequest, CalendarAgentMessage>(
    label: "calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    subscribeRequest: { [weak self] in
      CalendarAgentRequest(command: .subscribe, query: self?.currentQuery())
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: {
      DispatchQueue.main.async {
        NativeCalendarStore.shared.clear()
      }
    }
  )

  private init() {}

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    client.isConnected
  }

  /// Starts the calendar agent client.
  func start() {
    client.start()
  }

  /// Stops the calendar agent client.
  func stop() {
    client.stop()
  }

  /// Handles one incoming calendar-agent message.
  private func handle(_ message: CalendarAgentMessage) {
    switch message.kind {
    case .subscribed:
      Logger.info("calendar agent client subscribed")

    case .snapshot:
      guard let snapshot = message.snapshot else { return }
      publish(snapshot: snapshot)

    case .pong:
      break

    case .error:
      Logger.warn("calendar agent error=\(message.message ?? "unknown")")
    }
  }

  /// Returns the current calendar-agent query.
  ///
  /// The month calendar needs a wide symmetric event window so it can mark past
  /// and future days and resolve appointments when the user clicks old dates.
  private func currentQuery() -> CalendarAgentQuery {
    let calendarConfig = Config.shared.builtinCalendar
    let monthConfig = Config.shared.builtinMonthCalendar

    let requestedDays = max(
      calendarConfig.days,
      monthCalendarFetchDays(monthConfig: monthConfig)
    )

    Logger.debug(
      "calendar agent client query days=\(requestedDays) show_birthdays=\(calendarConfig.showBirthdays) included=\(monthConfig.includedCalendarNames) excluded=\(monthConfig.excludedCalendarNames)"
    )

    return CalendarAgentQuery(
      days: requestedDays,
      showBirthdays: calendarConfig.showBirthdays,
      emptyText: calendarConfig.emptyText,
      birthdaysTitle: calendarConfig.birthdaysTitle,
      birthdaysDateFormat: calendarConfig.birthdaysDateFormat,
      birthdaysShowAge: calendarConfig.birthdaysShowAge,
      includedCalendarNames: monthConfig.includedCalendarNames,
      excludedCalendarNames: monthConfig.excludedCalendarNames
    )
  }

  /// Returns the fetch window needed for the month calendar popup.
  ///
  /// `days` is interpreted by the updated agent as a symmetric window around
  /// today, so 400 means roughly 400 days in the past and 400 in the future.
  private func monthCalendarFetchDays(
    monthConfig: Config.MonthCalendarBuiltinConfig
  ) -> Int {
    guard monthConfig.enabled else { return 0 }
    return 400
  }

  /// Publishes one snapshot to the shared store on the main queue.
  private func publish(snapshot: CalendarAgentSnapshot) {
    DispatchQueue.main.async {
      Logger.debug(
        "calendar agent client publish snapshot events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
      )
      NativeCalendarStore.shared.apply(snapshot: snapshot)
      EventBus.shared.emit(.calendarChange)
    }
  }
}
