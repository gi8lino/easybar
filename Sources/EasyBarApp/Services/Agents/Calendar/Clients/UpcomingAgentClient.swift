import EasyBarCalendarPresentation
import EasyBarShared
import Foundation

@MainActor
final class UpcomingCalendarAgentClient {
  /// Shared upcoming-calendar agent client.
  static var shared = UpcomingCalendarAgentClient(
    logger: ProcessLogger(label: "easybar.bootstrap.upcoming_agent"),
    config: .shared
  )

  /// Configures the shared upcoming-calendar agent client.
  static func bootstrap(logger: ProcessLogger, config: Config = .shared) {
    shared = UpcomingCalendarAgentClient(logger: logger, config: config)
  }

  private let logger: ProcessLogger
  private let config: Config

  private lazy var stream: CalendarAgentStreamController = CalendarAgentStreamController(
    label: "upcoming calendar agent client",
    socketPath: { [config] in config.calendarAgentSocketPath },
    makeRequest: { [weak self] in
      self?.makeRequest() ?? CalendarAgentRequest(command: .ping)
    },
    applySnapshot: { snapshot in
      NativeUpcomingCalendarStore.shared.apply(snapshot: snapshot)
    },
    clearState: {
      NativeUpcomingCalendarStore.shared.clear()
    },
    logger: logger.child("stream")
  )

  init(logger: ProcessLogger, config: Config) {
    self.logger = logger
    self.config = config
  }

  /// Returns whether the upcoming-calendar agent client is currently active.
  var isConnected: Bool {
    return stream.isConnected
  }

  /// Starts the upcoming-calendar agent socket client when enabled.
  func start() {
    stream.start(enabled: config.calendarAgentEnabled)
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
    let calendarConfig = config.builtinCalendar
    let upcoming = calendarConfig.upcoming
    let options = calendarConfig.presentationUpcomingRequestOptions
    let requestedRange = CalendarRequestFactory.requestedUpcomingDateRange(
      now: now,
      dayCount: options.dayCount
    )

    logger.debug(
      "requesting upcoming calendar snapshot",
      .field("start", requestedRange.start.timeIntervalSince1970),
      .field("end", requestedRange.end.timeIntervalSince1970),
      .field("days", options.dayCount),
      .field("exclude_past_events", upcoming.events.excludePastEvents),
      .field("show_birthdays", options.birthdays.showBirthdays),
    )

    return CalendarRequestFactory.makeUpcomingSubscribeRequest(now: now, options: options)
  }
}
