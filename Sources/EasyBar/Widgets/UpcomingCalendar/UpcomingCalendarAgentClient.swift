import EasyBarShared
import Foundation

final class UpcomingCalendarAgentClient {

  static let shared = UpcomingCalendarAgentClient()

  private lazy var stream = CalendarAgentStreamController(
    label: "upcoming calendar agent client",
    socketPath: { Config.shared.calendarAgentSocketPath },
    makeRequest: { [weak self] in
      self?.makeRequest()
    },
    applySnapshot: { snapshot in
      NativeUpcomingCalendarStore.shared.apply(snapshot: snapshot)
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

  /// Builds the current upcoming-calendar fetch request.
  private func makeRequest() -> CalendarAgentRequestEnvelope {
    let now = Date()
    let config = Config.shared.builtinCalendar
    let upcoming = config.upcoming
    let requestedRange = CalendarNativeWidget.requestedDateRange(
      config: config,
      now: now
    )

    Logger.debug(
      "requesting upcoming calendar snapshot start=\(requestedRange.start.timeIntervalSince1970) end=\(requestedRange.end.timeIntervalSince1970) days=\(upcoming.events.days) show_birthdays=\(upcoming.birthdays.show)"
    )

    return .fetch(
      query: .upcoming(
        config: config,
        now: now,
        requestedRange: requestedRange
      )
    )
  }
}
