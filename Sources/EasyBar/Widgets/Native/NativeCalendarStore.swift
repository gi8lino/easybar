import Foundation
import EventKit

final class NativeCalendarStore: ObservableObject {

    static let shared = NativeCalendarStore()

    @Published private(set) var sections: [NativeCalendarPopupSection] = []

    private let eventStore = EKEventStore()

    private init() {}

    func refresh() {
        requestAccessIfNeeded()

        let config = Config.shared.builtinCalendar
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let endDate = calendar.date(
            byAdding: .day,
            value: max(1, config.days),
            to: startOfToday
        ) else {
            DispatchQueue.main.async {
                self.sections = []
            }
            return
        }

        var newSections: [NativeCalendarPopupSection] = []

        // Birthdays are rendered as their own independent section.
        if config.showBirthdays {
            newSections.append(makeBirthdaysSection(config: config, start: now, end: endDate))
        }

        // Only normal event calendars count as appointments.
        let normalCalendars = eventStore.calendars(for: .event).filter { $0.type != .birthday }

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: normalCalendars
        )

        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        for dayOffset in 0..<max(1, config.days) {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                continue
            }

            let dayEvents = events.filter { event in
                event.startDate >= day && event.startDate < nextDay
            }

            let title: String
            if calendar.isDateInToday(day) {
                title = "Today"
            } else if calendar.isDateInTomorrow(day) {
                title = "Tomorrow"
            } else {
                title = formatDayTitle(day)
            }

            let items: [NativeCalendarPopupItem]

            if dayEvents.isEmpty {
                // Show empty text for days without appointments.
                items = [
                    NativeCalendarPopupItem(
                        id: "empty-\(dayOffset)",
                        time: "",
                        title: config.emptyText
                    )
                ]
            } else {
                items = dayEvents.map { event in
                    NativeCalendarPopupItem(
                        id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                        time: event.isAllDay ? "All day" : formatEventTime(event.startDate),
                        title: normalizedTitle(event.title)
                    )
                }
            }

            newSections.append(
                NativeCalendarPopupSection(
                    id: "events-\(dayOffset)",
                    title: title,
                    items: items
                )
            )
        }

        DispatchQueue.main.async {
            self.sections = newSections
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.sections = []
        }
    }

    private func makeBirthdaysSection(
        config: Config.CalendarBuiltinConfig,
        start: Date,
        end: Date
    ) -> NativeCalendarPopupSection {
        let birthdayCalendars = eventStore.calendars(for: .event).filter { $0.type == .birthday }

        guard !birthdayCalendars.isEmpty else {
            return NativeCalendarPopupSection(
                id: "birthdays",
                title: config.birthdaysTitle,
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
                NativeCalendarPopupItem(
                    id: "birthday-\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                    time: formatBirthdayDate(event.startDate, format: config.birthdaysDateFormat),
                    title: birthdayTitle(for: event, showAge: config.birthdaysShowAge)
                )
            }

        return NativeCalendarPopupSection(
            id: "birthdays",
            title: config.birthdaysTitle,
            items: items
        )
    }

    private func birthdayTitle(for event: EKEvent, showAge: Bool) -> String {
        let title = normalizedTitle(event.title)

        guard showAge, let age = extractedAge(from: title) else {
            return title
        }

        return "\(title) (\(age))"
    }

    private func extractedAge(from title: String) -> Int? {
        // Apple birthday titles can already include age in some locales.
        // Keep this conservative and only use a trailing "(NN)" pattern.
        guard let open = title.lastIndex(of: "("),
              let close = title.lastIndex(of: ")"),
              open < close else {
            return nil
        }

        let value = title[title.index(after: open)..<close].trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(value)
    }

    private func requestAccessIfNeeded() {
        eventStore.requestFullAccessToEvents { granted, error in
            if let error {
                Logger.debug("calendar popup access request failed: \(error)")
                return
            }

            Logger.debug("calendar popup access granted: \(granted)")
        }
    }

    private func normalizedTitle(_ value: String?) -> String {
        guard let value else { return "Untitled" }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func formatBirthdayDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
