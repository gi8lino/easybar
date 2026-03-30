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
      "calendar agent authorization status before start=\(authState.describe(status))")

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
  ///
  /// `query.days` is interpreted as a symmetric window around today:
  /// - past `days`
  /// - future `days`
  ///
  /// This is required for the month calendar popup so it can:
  /// - mark days with events in the past and future
  /// - show appointments when a user clicks on a past day
  ///
  /// The rendered popup sections remain future-oriented for the regular
  /// calendar widget, but the raw event payload is symmetric.
  func snapshot(for query: CalendarAgentQuery) -> CalendarAgentSnapshot {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    let hasAccess = authState.effectiveAccessGranted()
    let permissionState = authState.permissionState()
    let now = Date()

    guard hasAccess else {
      AgentLogger.debug(
        "calendar snapshot access_granted=false permission_state=\(permissionState)")
      return CalendarAgentSnapshot(
        accessGranted: false,
        permissionState: permissionState,
        generatedAt: now,
        events: [],
        sections: []
      )
    }

    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: now)
    let safeDays = max(1, query.days)

    guard
      let fetchStart = calendar.date(byAdding: .day, value: -safeDays, to: startOfToday),
      let fetchEndExclusive = calendar.date(byAdding: .day, value: safeDays + 1, to: startOfToday),
      let sectionsEndExclusive = calendar.date(byAdding: .day, value: safeDays, to: startOfToday)
    else {
      return CalendarAgentSnapshot(
        accessGranted: true,
        permissionState: permissionState,
        generatedAt: now,
        events: [],
        sections: []
      )
    }

    let events = makeNormalizedEvents(
      query: query,
      fetchStart: fetchStart,
      fetchEndExclusive: fetchEndExclusive
    )

    let sections = makeSections(
      query: query,
      events: events,
      startOfToday: startOfToday,
      endExclusive: sectionsEndExclusive
    )

    let snapshot = CalendarAgentSnapshot(
      accessGranted: true,
      permissionState: permissionState,
      generatedAt: now,
      events: events,
      sections: sections
    )

    AgentLogger.debug(
      "calendar snapshot access_granted=true permission_state=\(permissionState) days=\(query.days) show_birthdays=\(query.showBirthdays) fetch_start=\(fetchStart) fetch_end=\(fetchEndExclusive) events=\(snapshot.events.count) sections=\(snapshot.sections.count)"
    )

    return snapshot
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
  /// Builds normalized events for the requested symmetric window.
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
  ///
  /// This loads all event calendars except the special birthday calendars,
  /// which are handled separately.
  private func makeRegularEvents(start: Date, end: Date) -> [CalendarAgentEvent] {
    let normalCalendars = eventStore.calendars(for: .event).filter { $0.type != .birthday }
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
          travelTimeSeconds: resolvedTravelTimeSeconds(for: event)
        )
      }
  }

  /// Resolves travel time from the best available source.
  ///
  /// Some SDK/target combinations don't surface `EKEvent.travelTime` to Swift
  /// even when the runtime may still provide it. This first tries KVC on the
  /// Objective-C object, then falls back to inferring travel time from alarms.
  private func resolvedTravelTimeSeconds(for event: EKEvent) -> TimeInterval? {
    if let direct = directTravelTimeSeconds(for: event) {
      return direct
    }

    return inferredTravelTimeSecondsFromAlarms(for: event)
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

  /// Infers travel time from alarms when available.
  ///
  /// This treats a negative relative alarm offset as lead time before the event.
  private func inferredTravelTimeSecondsFromAlarms(for event: EKEvent) -> TimeInterval? {
    guard let alarms = event.alarms, !alarms.isEmpty else { return nil }

    let candidates = alarms.compactMap { alarm -> TimeInterval? in
      let offset = alarm.relativeOffset
      guard offset < 0 else { return nil }
      return abs(offset)
    }

    return candidates.min()
  }
}

// MARK: - Section Building

extension CalendarSnapshotProvider {
  /// Builds simple rendered sections from normalized events.
  ///
  /// Sections remain future-oriented for the regular calendar popup, beginning
  /// with today and continuing for `query.days`. The month calendar popup does
  /// not use these sections; it uses the raw normalized events above.
  private func makeSections(
    query: CalendarAgentQuery,
    events: [CalendarAgentEvent],
    startOfToday: Date,
    endExclusive: Date
  ) -> [CalendarAgentSection] {
    let calendar = Calendar.current
    var sections: [CalendarAgentSection] = []

    let birthdayEvents = events.filter { event in
      event.isAllDay && event.id.hasPrefix("birthday-")
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
    let safeDays = max(1, query.days)

    for dayOffset in 0..<safeDays {
      guard
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
        day < endExclusive
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
      in: .whitespacesAndNewlines)
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
