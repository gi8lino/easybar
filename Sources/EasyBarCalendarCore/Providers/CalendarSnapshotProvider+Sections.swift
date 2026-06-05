import EasyBarShared
import Foundation

// MARK: - Section Building

extension CalendarSnapshotProvider {
  /// Builds simple rendered sections from normalized events.
  ///
  /// These sections are only for the regular calendar popup.
  func makeSections(
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

    for dayOffset in 0..<sectionDayCount {
      guard
        let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfSections),
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
      else {
        continue
      }

      let effectiveDayStart = max(day, sectionStartDate)
      let dayEvents = regularEvents.filter { event in
        event.startDate < nextDay && event.endDate > effectiveDayStart
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
              startDate: event.startDate,
              endDate: event.endDate,
              isAllDay: event.isAllDay,
              endTime: formattedEndTime(for: event),
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
}
