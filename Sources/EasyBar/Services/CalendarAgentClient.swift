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
        NativeUpcomingCalendarStore.shared.clear()
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
  private func currentQuery() -> CalendarAgentQuery {
    let now = Date()
    let config = Config.shared.builtinCalendar
    let requestedRange = UpcomingCalendarNativeWidget.requestedDateRange(
      config: config,
      now: now
    )

    Logger.debug(
      """
      calendar agent client query \
      start=\(debugDate(requestedRange.start)) \
      end=\(debugDate(requestedRange.end)) \
      section_start=\(debugDate(requestedRange.start)) \
      section_days=\(max(1, config.days)) \
      show_birthdays=\(config.showBirthdays)
      """
    )

    return CalendarAgentQuery(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: requestedRange.start,
      sectionDayCount: max(1, config.days),
      showBirthdays: config.showBirthdays,
      emptyText: config.emptyText,
      birthdaysTitle: config.birthdaysTitle,
      birthdaysDateFormat: config.birthdaysDateFormat,
      birthdaysShowAge: config.birthdaysShowAge,
      includedCalendarNames: [],
      excludedCalendarNames: []
    )
  }

  /// Publishes one snapshot to the shared store on the main queue.
  private func publish(snapshot: CalendarAgentSnapshot) {
    DispatchQueue.main.async {
      Logger.debug(
        "calendar agent client publish snapshot events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
      )
      NativeUpcomingCalendarStore.shared.apply(snapshot: snapshot)
      EventBus.shared.emit(.calendarChange)
    }
  }

  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
