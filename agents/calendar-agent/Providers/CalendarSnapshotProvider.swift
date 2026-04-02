import EasyBarShared
import EventKit
import Foundation

final class CalendarSnapshotProvider {
  private let eventStore = EKEventStore()
  private let authState = CalendarAgentAuthorizationState()
  private var didRequestAccess = false
  private var observer: NSObjectProtocol?
  private var onChange: (() -> Void)?

  /// Starts calendar access, observation, and change callbacks.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)
    AgentLogger.info(
      "calendar agent authorization status before start=\(authState.describe(status))"
    )

    requestAccessIfNeeded()

    observer = NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged,
      object: eventStore,
      queue: .main
    ) { [weak self] _ in
      AgentLogger.info("calendar store changed")
      self?.onChange?()
    }
  }

  /// Stops observing calendar store changes.
  func stop() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
  }

  /// Builds one calendar snapshot for the requested query.
  func snapshot(for query: CalendarAgentQuery) -> CalendarAgentSnapshot {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    let hasAccess = authState.effectiveAccessGranted()
    let permissionState = authState.permissionState()
    let now = Date()

    guard hasAccess else {
      AgentLogger.debug(
        "calendar snapshot access_granted=false permission_state=\(permissionState)"
      )
      return CalendarAgentSnapshot(
        accessGranted: false,
        permissionState: permissionState,
        generatedAt: now,
        writableCalendars: [],
        events: [],
        sections: []
      )
    }

    guard let fetchRange = normalizedFetchRange(from: query) else {
      AgentLogger.warn("calendar snapshot invalid fetch range")
      return CalendarAgentSnapshot(
        accessGranted: true,
        permissionState: permissionState,
        generatedAt: now,
        writableCalendars: writableCalendars(),
        events: [],
        sections: []
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

    AgentLogger.debug(
      """
      calendar snapshot access_granted=true \
      permission_state=\(permissionState) \
      fetch_start=\(fetchRange.start) \
      fetch_end=\(fetchRange.end) \
      section_start=\(String(describing: query.sectionStartDate)) \
      section_day_count=\(String(describing: query.sectionDayCount)) \
      show_birthdays=\(query.showBirthdays) \
      included=\(query.includedCalendarNames) \
      excluded=\(query.excludedCalendarNames) \
      writable_calendars=\(snapshot.writableCalendars.count) \
      events=\(snapshot.events.count) \
      sections=\(snapshot.sections.count)
      """
    )

    return snapshot
  }

  /// Creates one new calendar event through EventKit.
  @discardableResult
  func createEvent(_ draft: CalendarAgentCreateEvent) throws -> String {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    guard authState.effectiveAccessGranted() else {
      throw CalendarAgentCreateError.accessDenied
    }

    guard draft.startDate < draft.endDate else {
      throw CalendarAgentCreateError.invalidDateRange
    }

    let event = EKEvent(eventStore: eventStore)
    event.calendar = resolvedCalendar(named: draft.calendarName)
    event.title = normalizedTitle(draft.title)
    event.startDate = draft.startDate
    event.endDate = draft.endDate
    event.isAllDay = draft.isAllDay
    event.location = normalizedOptionalText(draft.location)

    if let travelTimeSeconds = draft.travelTimeSeconds, travelTimeSeconds > 0 {
      event.setValue(NSNumber(value: travelTimeSeconds), forKey: "travelTime")
    }

    event.alarms = draft.alertOffsetsSeconds.map { EKAlarm(relativeOffset: -abs($0)) }

    try eventStore.save(event, span: .thisEvent, commit: true)

    AgentLogger.info(
      """
      calendar event created \
      title=\(event.title ?? "Untitled") \
      start=\(draft.startDate) \
      end=\(draft.endDate) \
      all_day=\(draft.isAllDay) \
      calendar=\(event.calendar.title) \
      location=\(event.location ?? "")
      """
    )

    DispatchQueue.main.async { [weak self] in
      self?.onChange?()
    }

    return event.eventIdentifier ?? ""
  }

  /// Updates one existing calendar event through EventKit.
  func updateEvent(_ draft: CalendarAgentUpdateEvent) throws {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    guard authState.effectiveAccessGranted() else {
      throw CalendarAgentCreateError.accessDenied
    }

    guard let event = resolvedEvent(id: draft.eventIdentifier) else {
      throw CalendarAgentMutationError.eventNotFound
    }

    guard draft.startDate < draft.endDate else {
      throw CalendarAgentCreateError.invalidDateRange
    }

    event.calendar = resolvedCalendar(named: draft.calendarName)
    event.title = normalizedTitle(draft.title)
    event.startDate = draft.startDate
    event.endDate = draft.endDate
    event.isAllDay = draft.isAllDay
    event.location = normalizedOptionalText(draft.location)

    if let travelTimeSeconds = draft.travelTimeSeconds, travelTimeSeconds > 0 {
      event.setValue(NSNumber(value: travelTimeSeconds), forKey: "travelTime")
    } else {
      event.setValue(Optional<NSNumber>.none, forKey: "travelTime")
    }

    if draft.alertOffsetsSeconds.isEmpty {
      event.alarms = nil
    } else {
      event.alarms = draft.alertOffsetsSeconds.map { EKAlarm(relativeOffset: -abs($0)) }
    }

    try eventStore.save(event, span: .thisEvent, commit: true)

    AgentLogger.info(
      """
      calendar event updated \
      event_id=\(draft.eventIdentifier) \
      title=\(event.title ?? "Untitled") \
      start=\(draft.startDate) \
      end=\(draft.endDate) \
      all_day=\(draft.isAllDay) \
      calendar=\(event.calendar.title) \
      location=\(event.location ?? "")
      """
    )

    DispatchQueue.main.async { [weak self] in
      self?.onChange?()
    }
  }

  /// Deletes one existing calendar event through EventKit.
  func deleteEvent(_ draft: CalendarAgentDeleteEvent) throws {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    guard authState.effectiveAccessGranted() else {
      throw CalendarAgentCreateError.accessDenied
    }

    guard let event = resolvedEvent(id: draft.eventIdentifier) else {
      throw CalendarAgentMutationError.eventNotFound
    }

    try eventStore.remove(event, span: .thisEvent, commit: true)

    AgentLogger.info(
      "calendar event deleted event_id=\(draft.eventIdentifier) title=\(event.title ?? "Untitled")"
    )

    DispatchQueue.main.async { [weak self] in
      self?.onChange?()
    }
  }

  /// Returns one normalized fetch range when valid.
  private func normalizedFetchRange(from query: CalendarAgentQuery) -> DateInterval? {
    let start = min(query.startDate, query.endDate)
    let end = max(query.startDate, query.endDate)

    guard start < end else { return nil }
    return DateInterval(start: start, end: end)
  }

  /// Requests calendar access when the current state allows it.
  private func requestAccessIfNeeded() {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)
    AgentLogger.info("calendar agent access status=\(authState.describe(status))")

    switch status {
    case .authorized, .fullAccess:
      AgentLogger.info("calendar agent access already granted")
      onChange?()

    case .notDetermined:
      guard !didRequestAccess else { return }
      didRequestAccess = true

      AgentLogger.info("requesting calendar full access")
      eventStore.requestFullAccessToEvents { [weak self] granted, error in
        guard let self else { return }

        let newStatus = EKEventStore.authorizationStatus(for: .event)
        self.authState.setStatus(newStatus)

        if let error {
          AgentLogger.error(
            "calendar agent access request failed status=\(self.authState.describe(newStatus)) error=\(error)"
          )
          return
        }

        AgentLogger.info(
          "calendar agent access request completed granted=\(granted) status=\(self.authState.describe(newStatus))"
        )

        guard granted else { return }

        self.authState.markGrantedInProcess()
        DispatchQueue.main.async {
          self.onChange?()
        }
      }

    case .denied, .restricted, .writeOnly:
      AgentLogger.warn("calendar agent access unavailable status=\(authState.describe(status))")

    @unknown default:
      AgentLogger.warn("calendar agent access status unknown raw=\(status.rawValue)")
    }
  }
}

// MARK: - Event Building

extension CalendarSnapshotProvider {
  /// Builds normalized events for the requested fetch range.
  private func makeNormalizedEvents(
    query: CalendarAgentQuery,
    fetchStart: Date,
    fetchEndExclusive: Date
  ) -> [CalendarAgentEvent] {
    var result: [CalendarAgentEvent] = []

    result.append(
      contentsOf: makeBirthdayEvents(
        query: query,
        start: fetchStart,
        end: fetchEndExclusive
      )
    )

    result.append(
      contentsOf: makeRegularEvents(
        query: query,
        start: fetchStart,
        end: fetchEndExclusive
      )
    )

    return result.sorted { lhs, rhs in
      if lhs.startDate != rhs.startDate {
        return lhs.startDate < rhs.startDate
      }

      if lhs.endDate != rhs.endDate {
        return lhs.endDate < rhs.endDate
      }

      return lhs.id < rhs.id
    }
  }

  /// Builds normalized regular calendar events.
  private func makeRegularEvents(
    query: CalendarAgentQuery,
    start: Date,
    end: Date
  ) -> [CalendarAgentEvent] {
    let normalCalendars = filteredRegularCalendars(query: query)
    let predicate = eventStore.predicateForEvents(
      withStart: start,
      end: end,
      calendars: normalCalendars
    )

    return eventStore.events(matching: predicate)
      .sorted { lhs, rhs in
        if lhs.startDate != rhs.startDate {
          return lhs.startDate < rhs.startDate
        }

        if lhs.endDate != rhs.endDate {
          return lhs.endDate < rhs.endDate
        }

        return (lhs.eventIdentifier ?? "") < (rhs.eventIdentifier ?? "")
      }
      .map { event in
        CalendarAgentEvent(
          id:
            "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
          title: normalizedTitle(event.title),
          startDate: event.startDate,
          endDate: event.endDate,
          isAllDay: event.isAllDay,
          calendarName: normalizedTitle(event.calendar.title),
          calendarColorHex: colorHex(for: event.calendar.cgColor),
          location: normalizedOptionalText(event.location),
          alertOffsetsSeconds: visibleAlertOffsetsSeconds(for: event),
          isHoliday: isHolidayCalendar(event.calendar),
          hasAlert: hasVisibleAlert(for: event),
          travelTimeSeconds: resolvedTravelTimeSeconds(for: event)
        )
      }
  }

  /// Builds normalized birthday events when enabled.
  private func makeBirthdayEvents(
    query: CalendarAgentQuery,
    start: Date,
    end: Date
  ) -> [CalendarAgentEvent] {
    guard query.showBirthdays else { return [] }

    let birthdayCalendars = eventStore.calendars(for: .event).filter { $0.type == .birthday }
    guard !birthdayCalendars.isEmpty else { return [] }

    let predicate = eventStore.predicateForEvents(
      withStart: start,
      end: end,
      calendars: birthdayCalendars
    )

    return eventStore.events(matching: predicate)
      .sorted { lhs, rhs in
        if lhs.startDate != rhs.startDate {
          return lhs.startDate < rhs.startDate
        }

        if lhs.endDate != rhs.endDate {
          return lhs.endDate < rhs.endDate
        }

        return (lhs.eventIdentifier ?? "") < (rhs.eventIdentifier ?? "")
      }
      .map { event in
        CalendarAgentEvent(
          id:
            "birthday-\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
          title: birthdayTitle(for: event, showAge: query.birthdaysShowAge),
          startDate: event.startDate,
          endDate: event.endDate,
          isAllDay: true,
          calendarName: normalizedTitle(event.calendar.title),
          calendarColorHex: colorHex(for: event.calendar.cgColor),
          location: normalizedOptionalText(event.location),
          alertOffsetsSeconds: visibleAlertOffsetsSeconds(for: event),
          isHoliday: isHolidayCalendar(event.calendar),
          hasAlert: hasVisibleAlert(for: event),
          travelTimeSeconds: resolvedTravelTimeSeconds(for: event)
        )
      }
  }

  /// Returns writable non-birthday calendars for the composer.
  private func writableCalendars() -> [CalendarAgentWritableCalendar] {
    eventStore.calendars(for: .event)
      .filter { $0.type != .birthday && $0.allowsContentModifications }
      .sorted { lhs, rhs in
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
      }
      .map { calendar in
        CalendarAgentWritableCalendar(
          id: calendar.calendarIdentifier,
          title: calendar.title
        )
      }
  }

  /// Returns the filtered non-birthday calendars for the query.
  private func filteredRegularCalendars(query: CalendarAgentQuery) -> [EKCalendar] {
    let calendars = eventStore.calendars(for: .event).filter { $0.type != .birthday }
    let included = normalizedNameSet(query.includedCalendarNames)
    let excluded = normalizedNameSet(query.excludedCalendarNames)

    return calendars.filter { calendar in
      let normalizedTitle = normalizedCalendarName(calendar.title)

      if excluded.contains(normalizedTitle) {
        return false
      }

      if included.isEmpty {
        return true
      }

      return included.contains(normalizedTitle)
    }
  }

  /// Resolves one writable calendar for creation or update.
  private func resolvedCalendar(named name: String?) -> EKCalendar {
    let writableCalendars = eventStore.calendars(for: .event).filter { calendar in
      calendar.allowsContentModifications && calendar.type != .birthday
    }

    if let name = normalizedOptionalText(name) {
      let normalized = normalizedCalendarName(name)

      if let match = writableCalendars.first(where: {
        normalizedCalendarName($0.title) == normalized
      }) {
        return match
      }
    }

    if let defaultCalendar = eventStore.defaultCalendarForNewEvents,
      defaultCalendar.allowsContentModifications
    {
      return defaultCalendar
    }

    if let firstWritable = writableCalendars.first {
      return firstWritable
    }

    if let anyCalendar = eventStore.calendars(for: .event).first {
      return anyCalendar
    }

    fatalError("No EventKit calendar available for event creation")
  }

  /// Resolves one event by EventKit identifier.
  private func resolvedEvent(id: String) -> EKEvent? {
    let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    return eventStore.event(withIdentifier: trimmed)
  }

  /// Returns one normalized calendar-name set.
  private func normalizedNameSet(_ values: [String]) -> Set<String> {
    Set(
      values
        .map { normalizedCalendarName($0) }
        .filter { !$0.isEmpty }
    )
  }

  /// Normalizes one calendar name for matching.
  private func normalizedCalendarName(_ value: String) -> String {
    value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }

  /// Resolves travel time from the best available source.
  private func resolvedTravelTimeSeconds(for event: EKEvent) -> TimeInterval? {
    directTravelTimeSeconds(for: event)
  }

  /// Reads `travelTime` dynamically when the Objective-C runtime exposes it.
  private func directTravelTimeSeconds(for event: EKEvent) -> TimeInterval? {
    let selector = NSSelectorFromString("travelTime")
    guard event.responds(to: selector) else { return nil }

    if let value = event.value(forKey: "travelTime") as? NSNumber {
      let seconds = value.doubleValue
      return seconds > 0 ? seconds : nil
    }

    return nil
  }

  /// Returns whether the event has at least one visible non-travel alert.
  private func hasVisibleAlert(for event: EKEvent) -> Bool {
    !visibleAlertOffsetsSeconds(for: event).isEmpty
  }

  /// Returns visible non-travel alert lead times.
  private func visibleAlertOffsetsSeconds(for event: EKEvent) -> [TimeInterval] {
    guard let alarms = event.alarms, !alarms.isEmpty else { return [] }

    let travelTimeSeconds = directTravelTimeSeconds(for: event)
    return alarms.compactMap { alarm in
      let offset = alarm.relativeOffset
      guard offset <= 0 else { return nil }
      let seconds = abs(offset)

      if let travelTimeSeconds {
        guard seconds != travelTimeSeconds else { return nil }
      }

      return seconds
    }
  }

  /// Returns whether one calendar should be treated as a holiday calendar.
  private func isHolidayCalendar(_ calendar: EKCalendar) -> Bool {
    let candidates = [calendar.title, calendar.source.title]
      .map(normalizedCalendarName(_:))

    return candidates.contains { name in
      name.contains("holiday")
        || name.contains("holidays")
        || name.contains("feiertag")
        || name.contains("feiertage")
        || name.contains("jour ferie")
        || name.contains("jours feries")
    }
  }
}

// MARK: - Section Building

extension CalendarSnapshotProvider {
  /// Builds simple rendered sections from normalized events.
  ///
  /// These sections are only for the regular calendar popup.
  private func makeSections(
    query: CalendarAgentQuery,
    events: [CalendarAgentEvent]
  ) -> [CalendarAgentSection] {
    guard
      let sectionStartDate = query.sectionStartDate,
      let sectionDayCount = query.sectionDayCount,
      sectionDayCount > 0
    else {
      return []
    }

    let calendar = Calendar.current
    let startOfSections = calendar.startOfDay(for: sectionStartDate)
    var sections: [CalendarAgentSection] = []

    let endOfSections =
      calendar.date(byAdding: .day, value: sectionDayCount, to: startOfSections)
      ?? startOfSections.addingTimeInterval(TimeInterval(sectionDayCount * 86_400))

    let birthdayEvents = events.filter { event in
      event.isAllDay
        && event.id.hasPrefix("birthday-")
        && event.startDate < endOfSections
        && event.endDate > startOfSections
    }

    if query.showBirthdays {
      sections.append(
        CalendarAgentSection(
          id: "birthdays",
          title: query.birthdaysTitle,
          kind: .birthdays,
          items: birthdayEvents.map { event in
            CalendarAgentItem(
              id: event.id,
              time: formatBirthdayDate(event.startDate, format: query.birthdaysDateFormat),
              title: event.title,
              calendarName: event.calendarName,
              calendarColorHex: event.calendarColorHex,
              location: event.location,
              travelTimeSeconds: event.travelTimeSeconds
            )
          }
        )
      )
    }

    let regularEvents = events.filter { !$0.id.hasPrefix("birthday-") }

    for dayOffset in 0..<sectionDayCount {
      guard
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfSections),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
      else {
        continue
      }

      let dayEvents = regularEvents.filter { event in
        event.startDate < nextDay && event.endDate > day
      }

      let title: String
      let kind: CalendarAgentSectionKind

      if calendar.isDateInToday(day) {
        title = "Today"
        kind = .today
      } else if calendar.isDateInTomorrow(day) {
        title = "Tomorrow"
        kind = .tomorrow
      } else {
        title = formatDayTitle(day)
        kind = .future
      }

      guard !dayEvents.isEmpty else {
        sections.append(
          CalendarAgentSection(
            id: "events-\(dayOffset)",
            title: title,
            kind: kind,
            items: [CalendarAgentItem(id: "empty-\(dayOffset)", time: "", title: query.emptyText)]
          )
        )
        continue
      }

      sections.append(
        CalendarAgentSection(
          id: "events-\(dayOffset)",
          title: title,
          kind: kind,
          items: dayEvents.map { event in
            CalendarAgentItem(
              id: event.id,
              time: event.isAllDay ? "All day" : formatEventTime(event.startDate),
              title: event.title,
              calendarName: event.calendarName,
              calendarColorHex: event.calendarColorHex,
              location: event.location,
              travelTimeSeconds: event.travelTimeSeconds
            )
          }
        )
      )
    }

    return sections
  }
}

// MARK: - Formatting

extension CalendarSnapshotProvider {
  /// Returns one birthday title, optionally with age appended.
  private func birthdayTitle(for event: EKEvent, showAge: Bool) -> String {
    let title = normalizedTitle(event.title)

    guard showAge, let age = extractedAge(from: title) else {
      return title
    }

    return "\(title) (\(age))"
  }

  /// Extracts an age suffix from one birthday event title.
  private func extractedAge(from title: String) -> Int? {
    guard let open = title.lastIndex(of: "("),
      let close = title.lastIndex(of: ")"),
      open < close
    else {
      return nil
    }

    let value = title[title.index(after: open)..<close].trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    return Int(value)
  }

  /// Normalizes one optional title into display text.
  private func normalizedTitle(_ value: String?) -> String {
    guard let value else { return "Untitled" }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled" : trimmed
  }

  /// Normalizes optional text and drops empty strings.
  private func normalizedOptionalText(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Formats one event time for popup display.
  private func formatEventTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }

  /// Formats one day header for popup display.
  private func formatDayTitle(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter.string(from: date)
  }

  /// Formats one birthday date using the configured format.
  private func formatBirthdayDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    return formatter.string(from: date)
  }
}

// MARK: - Color Conversion

extension CalendarSnapshotProvider {
  /// Converts one calendar color into a hex string.
  private func colorHex(for cgColor: CGColor?) -> String? {
    guard let cgColor else { return nil }
    guard
      let color = cgColor.converted(
        to: CGColorSpace(name: CGColorSpace.sRGB)!,
        intent: .defaultIntent,
        options: nil
      )
    else {
      return nil
    }

    guard let components = color.components else { return nil }
    let values: [CGFloat]

    if components.count >= 3 {
      values = components
    } else if components.count == 2 {
      values = [components[0], components[0], components[0], components[1]]
    } else {
      return nil
    }

    let red = Int(max(0, min(255, round(values[0] * 255))))
    let green = Int(max(0, min(255, round(values[1] * 255))))
    let blue = Int(max(0, min(255, round(values[2] * 255))))

    return String(format: "#%02X%02X%02X", red, green, blue)
  }
}

enum CalendarAgentCreateError: Error {
  case accessDenied
  case invalidDateRange
}

enum CalendarAgentMutationError: Error {
  case eventNotFound
}
