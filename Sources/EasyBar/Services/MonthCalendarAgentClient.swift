import EasyBarShared
import Foundation

final class MonthCalendarAgentClient {
  static let shared = MonthCalendarAgentClient()

  private lazy var client = AgentSocketClient<CalendarAgentRequest, CalendarAgentMessage>(
    label: "month calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    subscribeRequest: { [weak self] in
      CalendarAgentRequest(command: .subscribe, query: self?.currentQuery())
    },
    handleMessage: { [weak self] message in
      self?.handle(message)
    },
    clearState: {
      DispatchQueue.main.async {
        NativeMonthCalendarStore.shared.clear()
      }
    }
  )

  private init() {}

  /// Returns whether the client currently has an open socket.
  var isConnected: Bool {
    client.isConnected
  }

  /// Starts the calendar agent client for the month calendar widget.
  func start() {
    client.start()
  }

  /// Stops the calendar agent client for the month calendar widget.
  func stop() {
    client.stop()
  }

  /// Refreshes the month-calendar subscription when the visible month moves outside
  /// the currently prepared preload window.
  func refreshMonthSubscriptionIfNeeded(for visibleMonth: Date) {
    let changed = NativeMonthCalendarStore.shared.prepareMonthSubscriptionRange(for: visibleMonth)
    guard changed else { return }

    Logger.debug("month calendar agent client refresh requested")

    if isConnected {
      client.stop()
    }

    client.start()
  }

  /// Handles one incoming calendar-agent message.
  private func handle(_ message: CalendarAgentMessage) {
    switch message.kind {
    case .subscribed:
      Logger.info("month calendar agent client subscribed")

    case .snapshot:
      guard let snapshot = message.snapshot else { return }
      publish(snapshot: snapshot)

    case .pong:
      break

    case .error:
      Logger.warn("month calendar agent error=\(message.message ?? "unknown")")
    }
  }

  /// Returns the current calendar-agent query for the month calendar widget.
  private func currentQuery() -> CalendarAgentQuery {
    let now = Date()
    let config = Config.shared.builtinMonthCalendar

    let requestedRange: DateInterval
    if let prepared = NativeMonthCalendarStore.shared.monthSubscriptionRange() {
      requestedRange = DateInterval(start: prepared.start, end: prepared.end)
    } else {
      requestedRange = MonthCalendarNativeWidget.requestedDateRange(
        config: config,
        referenceDate: now
      )
    }

    Logger.debug(
      """
      month calendar agent client query \
      start=\(debugDate(requestedRange.start)) \
      end=\(debugDate(requestedRange.end)) \
      included=\(config.includedCalendarNames) \
      excluded=\(config.excludedCalendarNames)
      """
    )

    return CalendarAgentQuery(
      startDate: requestedRange.start,
      endDate: requestedRange.end,
      sectionStartDate: nil,
      sectionDayCount: nil,
      showBirthdays: true,
      emptyText: config.emptyText,
      birthdaysTitle: "Birthdays",
      birthdaysDateFormat: "dd.MM.yyyy",
      birthdaysShowAge: false,
      includedCalendarNames: config.includedCalendarNames,
      excludedCalendarNames: config.excludedCalendarNames
    )
  }

  /// Publishes one snapshot to the month calendar store on the main queue.
  private func publish(snapshot: CalendarAgentSnapshot) {
    DispatchQueue.main.async {
      Logger.debug(
        "month calendar agent client publish snapshot events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
      )
      NativeMonthCalendarStore.shared.apply(snapshot: snapshot)
      EventBus.shared.emit(.calendarChange)
    }
  }

  /// Formats one debug date string.
  private func debugDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    return formatter.string(from: date)
  }
}
