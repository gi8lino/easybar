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
  func snapshot(for query: CalendarAgentQuery) -> CalendarAgentSnapshot {
    let status = EKEventStore.authorizationStatus(for: .event)
    authState.setStatus(status)

    let hasAccess = authState.effectiveAccessGranted()
    let permissionState = authState.permissionState()

    guard hasAccess else {
      AgentLogger.debug(
        "calendar snapshot access_granted=false permission_state=\(permissionState)")
      return CalendarAgentSnapshot(
        accessGranted: false,
        permissionState: permissionState,
        generatedAt: Date(),
        sections: []
      )
    }

    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)

    guard let endDate = calendar.date(byAdding: .day, value: max(1, query.days), to: startOfToday)
    else {
      return CalendarAgentSnapshot(
        accessGranted: true,
        permissionState: permissionState,
        generatedAt: now,
        sections: []
      )
    }

    var sections: [CalendarAgentSection] = []

    if query.showBirthdays {
      sections.append(makeBirthdaysSection(query: query, start: now, end: endDate))
    }

    let normalCalendars = eventStore.calendars(for: .event).filter { $0.type != .birthday }
    let predicate = eventStore.predicateForEvents(
      withStart: startOfToday,
      end: endDate,
      calendars: normalCalendars
    )

    let events = eventStore.events(matching: predicate)
      .sorted { $0.startDate < $1.startDate }

    for dayOffset in 0..<max(1, query.days) {
      guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
      else {
        continue
      }

      let dayEvents = events.filter { event in
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

      // Keep empty days visible so the popup layout stays stable.
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

      let items = dayEvents.map { event in
        CalendarAgentItem(
          id:
            "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
          time: event.isAllDay ? "All day" : formatEventTime(event.startDate),
          title: normalizedTitle(event.title),
          calendarName: normalizedTitle(event.calendar.title),
          calendarColorHex: colorHex(for: event.calendar.cgColor)
        )
      }

      sections.append(
        CalendarAgentSection(
          id: "events-\(dayOffset)",
          title: title,
          kind: kind,
          items: items
        )
      )
    }

    let snapshot = CalendarAgentSnapshot(
      accessGranted: true,
      permissionState: permissionState,
      generatedAt: now,
      sections: sections
    )

    AgentLogger.debug(
      "calendar snapshot access_granted=true permission_state=\(permissionState) days=\(query.days) show_birthdays=\(query.showBirthdays) sections=\(snapshot.sections.count)"
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

  /// Builds the birthdays section for one query window.
  private func makeBirthdaysSection(
    query: CalendarAgentQuery,
    start: Date,
    end: Date
  ) -> CalendarAgentSection {
    let birthdayCalendars = eventStore.calendars(for: .event).filter { $0.type == .birthday }

    guard !birthdayCalendars.isEmpty else {
      return CalendarAgentSection(
        id: "birthdays",
        title: query.birthdaysTitle,
        kind: .birthdays,
        items: []
      )
    }

    let predicate = eventStore.predicateForEvents(
      withStart: start,
      end: end,
      calendars: birthdayCalendars
    )

    let items = eventStore.events(matching: predicate)
      .sorted { $0.startDate < $1.startDate }
      .map { event in
        CalendarAgentItem(
          id:
            "birthday-\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
          time: formatBirthdayDate(event.startDate, format: query.birthdaysDateFormat),
          title: birthdayTitle(for: event, showAge: query.birthdaysShowAge),
          calendarName: normalizedTitle(event.calendar.title),
          calendarColorHex: colorHex(for: event.calendar.cgColor)
        )
      }

    return CalendarAgentSection(
      id: "birthdays",
      title: query.birthdaysTitle,
      kind: .birthdays,
      items: items
    )
  }

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

  /// Converts one calendar color into a hex string.
  private func colorHex(for cgColor: CGColor?) -> String? {
    guard let cgColor else { return nil }
    guard
      let color = cgColor.converted(
        to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)
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
