import EasyBarShared
import EventKit
import Foundation

/// Builds calendar snapshots and applies calendar event mutations.
final class CalendarSnapshotProvider: @unchecked Sendable {
  /// Bridges EventKit travel-time storage that is not exposed as public Swift API.
  enum EventTravelTimeBridge {
    /// Key-value coding key used by EventKit for travel time.
    static let key = "travelTime"
    /// Getter selector used to verify that the current EventKit object supports travel time.
    static let getterSelector = NSSelectorFromString(key)
    /// Setter selector used to avoid an Objective-C exception for unsupported KVC writes.
    static let setterSelector = NSSelectorFromString("setTravelTime:")

    /// Reads positive travel time from one compatible object.
    static func getSeconds(from object: NSObject) -> TimeInterval? {
      guard object.responds(to: getterSelector) else { return nil }

      if let value = object.value(forKey: key) as? NSNumber {
        let seconds = value.doubleValue
        return seconds > 0 ? seconds : nil
      }

      return nil
    }

    /// Writes travel time only when the current object exposes the matching setter.
    @discardableResult
    static func setSeconds(_ seconds: TimeInterval?, on object: NSObject) -> Bool {
      guard object.responds(to: setterSelector) else { return false }

      let normalizedSeconds = max(0, seconds ?? 0)
      object.setValue(NSNumber(value: normalizedSeconds), forKey: key)
      return true
    }
  }

  /// Locale used for stable date formatting.
  static let formatterLocale = Locale(identifier: "en_US_POSIX")
  /// Calendar used for stable date formatting.
  static let formatterCalendar = Calendar(identifier: .gregorian)
  /// Time zone used for user-facing calendar output.
  static let formatterTimeZone = TimeZone.autoupdatingCurrent
  /// Cached birthday formatters keyed by format string.
  static let birthdayFormatters = LockedState([String: DateFormatter]())

  /// Formatter for timed event rows.
  static let eventTimeFormatter: DateFormatter = makeFormatter(format: "HH:mm")
  /// Formatter for future day section titles.
  static let dayTitleFormatter: DateFormatter = makeFormatter(format: "dd.MM.yyyy")

  /// EventKit store used for reads and mutations.
  let eventStore = EKEventStore()
  /// Shared authorization state used by the provider and controller.
  private let authState = CalendarAuthorizationState()
  /// Logger used for snapshot and mutation diagnostics.
  private let logger: ProcessLogger
  /// Controller that owns calendar permission flow.
  private let authorizationController: CalendarAuthorizationController
  /// EventKit change observer token.
  private var observer: NSObjectProtocol?
  /// Callback invoked when calendar data may have changed.
  private var onChange: (() -> Void)?

  /// Creates one calendar snapshot provider that logs through the provided logger.
  init(logger: ProcessLogger) {
    self.logger = logger
    authorizationController = CalendarAuthorizationController(
      eventStore: eventStore,
      authState: authState,
      logger: logger.child("authorization")
    )
  }

  /// Starts calendar access, observation, and change callbacks.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    authorizationController.start { [weak self] in
      self?.onChange?()
    }

    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: eventStore,
      queue: .main
    ) { [weak self] _ in
      self?.logger.info("calendar store changed")
      self?.onChange?()
    }
  }

  /// Stops observing calendar store changes.
  func stop() {
    authorizationController.stop()

    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }

    onChange = nil
  }

  /// Builds one calendar snapshot for the requested query.
  func snapshot(for query: CalendarAgentQuery) -> CalendarAgentSnapshot {
    authorizationController.refreshStatus()

    let hasAccess = authorizationController.effectiveAccessGranted()
    let permissionState = authorizationController.permissionState()
    let now = Date()

    guard hasAccess else {
      logger.debug(
        "calendar snapshot",
        .field("access_granted", false),
        .field("permission_state", permissionState),
      )
      return makeAccessDeniedSnapshot(permissionState: permissionState, generatedAt: now)
    }

    guard let fetchRange = normalizedFetchRange(from: query) else {
      logger.warn("calendar snapshot invalid fetch range")
      return makeEmptySnapshot(
        permissionState: permissionState,
        generatedAt: now,
        writableCalendars: writableCalendars()
      )
    }

    let events = makeNormalizedEvents(
      query: query,
      fetchStart: fetchRange.start,
      fetchEndExclusive: fetchRange.end
    )

    let sections = makeSections(
      query: query,
      events: events
    )

    let snapshot = CalendarAgentSnapshot(
      accessGranted: true,
      permissionState: permissionState,
      generatedAt: now,
      writableCalendars: writableCalendars(),
      events: events,
      sections: sections
    )

    logger.debug(
      "calendar snapshot",
      .field("access_granted", true),
      .field("permission_state", permissionState),
      .field("fetch_start", fetchRange.start),
      .field("fetch_end", fetchRange.end),
      .field("section_start", String(describing: query.sectionStartDate)),
      .field("section_day_count", String(describing: query.sectionDayCount)),
      .field("show_birthdays", query.showBirthdays),
      .field("included_calendar_names", query.includedCalendarNames),
      .field("excluded_calendar_names", query.excludedCalendarNames),
      .field("included_calendar_ids", query.includedCalendarIDs),
      .field("excluded_calendar_ids", query.excludedCalendarIDs),
      .field("included_calendar_source_ids", query.includedCalendarSourceIDs),
      .field("excluded_calendar_source_ids", query.excludedCalendarSourceIDs),
      .field("writable_calendars", snapshot.writableCalendars.count),
      .field("events", snapshot.events.count),
      .field("sections", snapshot.sections.count),
    )

    return snapshot
  }

  /// Creates one new calendar event through EventKit.
  @discardableResult
  func createEvent(_ draft: CalendarAgentCreateEvent) throws -> String {
    authorizationController.refreshStatus()

    guard authorizationController.effectiveAccessGranted() else {
      throw CalendarAgentCreateError.accessDenied
    }

    guard draft.startDate < draft.endDate else {
      throw CalendarAgentCreateError.invalidDateRange
    }

    let event = EKEvent(eventStore: eventStore)
    event.calendar = try resolvedCalendar(id: draft.calendarID)
    event.title = normalizedTitle(draft.title)
    event.startDate = draft.startDate
    event.endDate = draft.endDate
    event.isAllDay = draft.isAllDay
    event.location = normalizedOptionalText(draft.location)
    applyTravelTime(draft.travelTimeSeconds, to: event)
    event.alarms = draft.alertOffsetsSeconds.map { EKAlarm(relativeOffset: -abs($0)) }

    try eventStore.save(event, span: .thisEvent, commit: true)

    logger.info(
      "calendar event created",
      .field("title", event.title ?? "Untitled"),
      .field("start", draft.startDate),
      .field("end", draft.endDate),
      .field("all_day", draft.isAllDay),
      .field("calendar", event.calendar.title),
      .field("location", event.location ?? ""),
    )

    Task { @MainActor [weak self] in
      self?.onChange?()
    }

    return event.eventIdentifier ?? ""
  }

  /// Updates one existing calendar event through EventKit.
  func updateEvent(_ draft: CalendarAgentUpdateEvent) throws {
    authorizationController.refreshStatus()

    guard authorizationController.effectiveAccessGranted() else {
      throw CalendarAgentCreateError.accessDenied
    }

    guard let event = resolvedEvent(id: draft.eventIdentifier) else {
      throw CalendarAgentMutationError.eventNotFound
    }

    guard draft.startDate < draft.endDate else {
      throw CalendarAgentCreateError.invalidDateRange
    }

    event.calendar = try resolvedCalendar(id: draft.calendarID)
    event.title = normalizedTitle(draft.title)
    event.startDate = draft.startDate
    event.endDate = draft.endDate
    event.isAllDay = draft.isAllDay
    event.location = normalizedOptionalText(draft.location)
    applyTravelTime(draft.travelTimeSeconds, to: event)

    if draft.alertOffsetsSeconds.isEmpty {
      event.alarms = nil
    } else {
      event.alarms = draft.alertOffsetsSeconds.map { EKAlarm(relativeOffset: -abs($0)) }
    }

    try eventStore.save(event, span: .thisEvent, commit: true)

    logger.info(
      "calendar event updated",
      .field("event_id", draft.eventIdentifier),
      .field("title", event.title ?? "Untitled"),
      .field("start", draft.startDate),
      .field("end", draft.endDate),
      .field("all_day", draft.isAllDay),
      .field("calendar", event.calendar.title),
      .field("location", event.location ?? ""),
    )

    Task { @MainActor [weak self] in
      self?.onChange?()
    }
  }

  /// Deletes one existing calendar event through EventKit.
  func deleteEvent(_ draft: CalendarAgentDeleteEvent) throws {
    authorizationController.refreshStatus()

    guard authorizationController.effectiveAccessGranted() else {
      throw CalendarAgentCreateError.accessDenied
    }

    guard let event = resolvedEvent(id: draft.eventIdentifier) else {
      throw CalendarAgentMutationError.eventNotFound
    }

    try eventStore.remove(event, span: .thisEvent, commit: true)

    logger.info(
      "calendar event deleted",
      .field("event_id", draft.eventIdentifier),
      .field("title", event.title ?? "Untitled"),
    )

    Task { @MainActor [weak self] in
      self?.onChange?()
    }
  }

  /// Applies EventKit travel time when the current macOS implementation supports it.
  private func applyTravelTime(_ seconds: TimeInterval?, to event: EKEvent) {
    guard !EventTravelTimeBridge.setSeconds(seconds, on: event), seconds != nil else { return }

    logger.debug(
      "calendar event travel time unsupported",
      .field("seconds", seconds ?? 0)
    )
  }

  /// Returns one normalized fetch range when valid.
  private func normalizedFetchRange(from query: CalendarAgentQuery) -> DateInterval? {
    let start = min(query.startDate, query.endDate)
    let end = max(query.startDate, query.endDate)

    guard start < end else { return nil }
    return DateInterval(start: start, end: end)
  }

  /// Returns one empty snapshot for denied access.
  private func makeAccessDeniedSnapshot(
    permissionState: String,
    generatedAt: Date
  ) -> CalendarAgentSnapshot {
    CalendarAgentSnapshot(
      accessGranted: false,
      permissionState: permissionState,
      generatedAt: generatedAt,
      writableCalendars: [],
      events: [],
      sections: []
    )
  }

  /// Returns one empty successful snapshot.
  private func makeEmptySnapshot(
    permissionState: String,
    generatedAt: Date,
    writableCalendars: [CalendarAgentWritableCalendar]
  ) -> CalendarAgentSnapshot {
    CalendarAgentSnapshot(
      accessGranted: true,
      permissionState: permissionState,
      generatedAt: generatedAt,
      writableCalendars: writableCalendars,
      events: [],
      sections: []
    )
  }

  /// Creates one stable formatter for deterministic popup rendering.
  static func makeFormatter(format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = formatterLocale
    formatter.calendar = formatterCalendar
    formatter.timeZone = formatterTimeZone
    formatter.dateFormat = format
    return formatter
  }

  /// Returns a cached birthday formatter for one format string.
  static func birthdayFormatter(for format: String) -> DateFormatter {
    birthdayFormatters.withLock { formatters in
      if let formatter = formatters[format] {
        return formatter
      }

      let formatter = makeFormatter(format: format)
      formatters[format] = formatter
      return formatter
    }
  }
}
