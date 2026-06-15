import EasyBarCalendarPresentation
import EasyBarShared
import Foundation

/// Agent client used by the reusable month-calendar popup.
@MainActor
final class MonthCalendarAgentClient {
  /// Shared month-calendar agent client instance.
  static var shared = MonthCalendarAgentClient(
    logger: ProcessLogger(label: "easybar.bootstrap.month_agent"),
    calendarAgentConfig: Config.makeUnloadedConfig().snapshot().calendarAgent,
    calendarConfig: Config.makeUnloadedConfig().snapshot().builtins.calendar
  )

  /// Configures the shared month-calendar agent client.
  static func bootstrap(logger: ProcessLogger, snapshot: ConfigSnapshot) {
    shared = MonthCalendarAgentClient(
      logger: logger,
      calendarAgentConfig: snapshot.calendarAgent,
      calendarConfig: snapshot.builtins.calendar
    )
  }

  /// Logger used for month-calendar agent diagnostics.
  private let logger: ProcessLogger
  /// Active calendar-agent config snapshot.
  private var calendarAgentConfig: ConfigSnapshot.CalendarAgent
  /// Active calendar built-in config snapshot.
  private var calendarConfig: Config.CalendarBuiltinConfig

  /// Month radii loaded around the currently visible month.
  private let preloadRadii = [0, 1, 2, 3, 4, 5, 6]

  /// Delay schedule for staged month preload requests.
  private let preloadDelays: [TimeInterval] = [0.0, 0.20, 0.75, 1.75, 3.5, 6.5, 10.0]

  /// Pending staged month preload tasks.
  private var preloadTasks: [Task<Void, Never>] = []

  /// Long-lived calendar-agent stream controller.
  private lazy var stream: CalendarAgentStreamController = CalendarAgentStreamController(
    label: "month calendar agent client",
    socketPath: { [weak self] in self?.calendarAgentConfig.socketPath ?? "" },
    makeRequest: { [weak self] in
      self?.makeRequest() ?? CalendarAgentRequest(command: .ping)
    },
    applySnapshot: { snapshot in
      NativeMonthCalendarStore.shared.apply(snapshot: snapshot)
    },
    clearState: {
      NativeMonthCalendarStore.shared.clear()
    },
    logger: logger.child("stream")
  )

  /// Creates one month-calendar agent client.
  init(
    logger: ProcessLogger,
    calendarAgentConfig: ConfigSnapshot.CalendarAgent,
    calendarConfig: Config.CalendarBuiltinConfig
  ) {
    self.logger = logger
    self.calendarAgentConfig = calendarAgentConfig
    self.calendarConfig = calendarConfig
  }

  /// Returns whether the month-calendar agent client is currently active.
  var isConnected: Bool {
    return stream.isConnected
  }

  /// Replaces the active calendar config snapshots.
  func updateConfiguration(
    calendarAgentConfig: ConfigSnapshot.CalendarAgent,
    calendarConfig: Config.CalendarBuiltinConfig
  ) {
    let streamConfigChanged = self.calendarAgentConfig.requiresStreamRestart(
      for: calendarAgentConfig
    )

    self.calendarAgentConfig = calendarAgentConfig
    self.calendarConfig = calendarConfig

    guard stream.isStarted else { return }

    if streamConfigChanged {
      stream.restart(enabled: calendarAgentConfig.enabled)
      return
    }

    refresh()
  }

  /// Starts the month-calendar agent socket client when enabled.
  func start() {
    stream.start(enabled: calendarAgentConfig.enabled)
  }

  /// Stops the month-calendar agent socket client.
  func stop() {
    cancelStagedPreload()
    stream.stop()
  }

  /// Starts staged month loading centered on the visible month.
  func focusVisibleMonth(_ visibleMonth: Date) {
    cancelStagedPreload()

    for (index, radius) in preloadRadii.enumerated() {
      let delay = preloadDelays[min(index, preloadDelays.count - 1)]
      let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
      let task = Task { @MainActor in
        do {
          try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
          return
        }

        MonthCalendarAgentClient.shared.refreshMonthSubscriptionIfNeeded(
          for: visibleMonth,
          radius: radius
        )
      }

      preloadTasks.append(task)
    }
  }

  /// Refreshes the active month subscription if the preload window changed.
  func refreshMonthSubscriptionIfNeeded(for visibleMonth: Date, radius: Int) {
    let calendar = resolvedCalendar()
    let changed = NativeMonthCalendarStore.shared.prepareMonthSubscriptionRange(
      for: visibleMonth,
      radius: radius,
      calendar: calendar
    )
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
    let socketPath = calendarAgentConfig.socketPath

    Task.detached(priority: .userInitiated) {
      do {
        let response = try CalendarAgentOneShotClient.send(
          request: request,
          socketPath: socketPath
        )

        await MainActor.run {
          MonthCalendarAgentClient.shared.handleMutationResponse(
            response,
            successKind: successKind,
            completion: completion
          )
        }
      } catch {
        await MainActor.run {
          MonthCalendarAgentClient.shared.handleMutationError(
            error,
            completion: completion
          )
        }
      }
    }
  }

  /// Handles one calendar-agent mutation response on the main actor.
  private func handleMutationResponse(
    _ response: CalendarAgentMessage,
    successKind: CalendarAgentMessageKind,
    completion: (_ success: Bool, _ message: String?) -> Void
  ) {
    switch response.kind {
    case successKind:
      refresh()
      UpcomingCalendarAgentClient.shared.refresh()
      ComposerCalendarAgentClient.shared.refresh()
      completion(true, nil)

    case .error:
      let message = response.message ?? "unknown"
      logger.error(
        "month calendar mutation failed",
        .field("message", message)
      )
      completion(false, message)

    default:
      logger.error(
        "month calendar mutation unexpected response",
        .field("response", response.kind.rawValue)
      )
      completion(false, "unexpected_response")
    }
  }

  /// Handles one calendar-agent mutation failure on the main actor.
  private func handleMutationError(
    _ error: Error,
    completion: (_ success: Bool, _ message: String?) -> Void
  ) {
    logger.error(
      "month calendar mutation failed",
      .field("error", error)
    )
    completion(false, error.localizedDescription)
  }

  /// Builds the current month-calendar fetch request.
  private func makeRequest() -> CalendarAgentRequest {
    let requestedRange: DateInterval

    if let prepared = NativeMonthCalendarStore.shared.monthSubscriptionRange() {
      requestedRange = DateInterval(start: prepared.start, end: prepared.end)
    } else {
      requestedRange = defaultRequestedDateRange(referenceDate: Date())
    }

    let options = calendarConfig.presentationMonthRequestOptions

    logger.debug(
      "requesting month calendar snapshot",
      .field("start", requestedRange.start.timeIntervalSince1970),
      .field("end", requestedRange.end.timeIntervalSince1970),
      .field("show_birthdays", options.birthdays.showBirthdays),
      .field("birthdays_show_age", options.birthdays.showAge)
    )

    return CalendarRequestFactory.makeMonthSubscribeRequest(
      range: requestedRange,
      options: options
    )
  }

  /// Returns the default month preload range around the given reference date.
  private func defaultRequestedDateRange(referenceDate: Date) -> DateInterval {
    let calendar = resolvedCalendar()
    let currentMonthStart = CalendarMonthRangeBuilder.startOfMonth(referenceDate, calendar: calendar)

    return CalendarMonthRangeBuilder.visibleGridRange(for: currentMonthStart, calendar: calendar)
      ?? DateInterval(
        start: currentMonthStart,
        end:
          calendar.date(byAdding: .month, value: 1, to: currentMonthStart)
          ?? referenceDate.addingTimeInterval(31 * 86_400)
      )
  }

  /// Cancels any pending staged month expansion.
  private func cancelStagedPreload() {
    for preloadTask in preloadTasks {
      preloadTask.cancel()
    }
    preloadTasks.removeAll()
  }

  /// Returns the calendar resolved for month-grid subscription ranges.
  private func resolvedCalendar() -> Calendar {
    var calendar = Calendar.current

    if let firstWeekday = calendarConfig.month.popup.firstWeekday {
      calendar.firstWeekday = firstWeekday
    }

    return calendar
  }

}
