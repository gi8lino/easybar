import EasyBarShared
import Foundation

// MARK: - Section Building

extension CalendarSnapshotProvider {
  /// Builds simple rendered sections from normalized events.
  ///
  /// Events are bucketed once by their overlapping section days so the work scales
  /// with actual event/day overlaps instead of rescanning every event for every day.
  func makeSections(
    query: CalendarAgentQuery,
    events: [CalendarAgentEvent]
  ) -> [CalendarAgentSection] {
    guard
      let sectionStartDate = query.sectionStartDate,
      let sectionDayCount = query.sectionDayCount,
      (1...CalendarAgentRequestLimits.maximumSectionDayCount).contains(sectionDayCount)
    else {
      return []
    }

    let calendar = Calendar.current
    let startOfSections = calendar.startOfDay(for: sectionStartDate)
    guard
      let endOfSections = calendar.date(
        byAdding: .day,
        value: sectionDayCount,
        to: startOfSections
      )
    else {
      return []
    }

    var sections: [CalendarAgentSection] = []
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
              startDate: event.startDate,
              endDate: event.endDate,
              isAllDay: true,
              title: event.title,
              calendarName: event.calendarName,
              calendarColorHex: event.calendarColorHex,
              location: event.location,
              url: event.url,
              travelTimeSeconds: event.travelTimeSeconds
            )
          }
        )
      )
    }

    let regularEvents = events.filter { !$0.id.hasPrefix("birthday-") }
    let eventsByDay = CalendarSectionBucketer.bucket(
      events: regularEvents,
      sectionStartDate: sectionStartDate,
      dayCount: sectionDayCount,
      calendar: calendar
    )
    guard eventsByDay.count == sectionDayCount else { return sections }

    for dayOffset in 0..<sectionDayCount {
      guard
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfSections),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
      else {
        continue
      }

      let effectiveDayStart = max(day, sectionStartDate)
      let dayEvents = eventsByDay[dayOffset]
      let (title, kind) = sectionHeading(for: day, query: query, calendar: calendar)

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
            let displayedStart = max(event.startDate, effectiveDayStart)
            let displayedEnd = min(event.endDate, nextDay)
            return CalendarAgentItem(
              id: "\(event.id)-day-\(dayOffset)",
              time: event.isAllDay ? query.allDayLabel : formatEventTime(displayedStart),
              startDate: displayedStart,
              endDate: displayedEnd,
              isAllDay: event.isAllDay,
              endTime: formattedEndTime(
                startDate: displayedStart,
                endDate: displayedEnd,
                isAllDay: event.isAllDay
              ),
              title: event.title,
              calendarName: event.calendarName,
              calendarColorHex: event.calendarColorHex,
              location: event.location,
              url: event.url,
              travelTimeSeconds: event.travelTimeSeconds
            )
          }
        )
      )
    }

    return sections
  }

  /// Resolves one localized section heading.
  private func sectionHeading(
    for day: Date,
    query: CalendarAgentQuery,
    calendar: Calendar
  ) -> (String, CalendarAgentSectionKind) {
    if calendar.isDateInToday(day) {
      return (query.todayTitle, .today)
    }
    if calendar.isDateInTomorrow(day) {
      return (query.tomorrowTitle, .tomorrow)
    }
    return (formatDayTitle(day), .future)
  }
}
