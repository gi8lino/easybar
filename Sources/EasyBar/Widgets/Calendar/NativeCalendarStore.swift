import Foundation
import EventKit

final class NativeCalendarStore: ObservableObject {

    static let shared = NativeCalendarStore()

    @Published private(set) var sections: [NativeCalendarPopupSection] = []

    private let eventStore = EKEventStore()
    private var didRequestAccess = false

    private init() {}

    func refresh() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            break

        case .notDetermined:
            requestAccessIfNeeded()
            DispatchQueue.main.async {
                self.sections = []
            }
            return

        case .denied, .restricted, .writeOnly:
            DispatchQueue.main.async {
                self.sections = []
            }
            return

        @unknown default:
            DispatchQueue.main.async {
                self.sections = []
            }
            return
        }

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
            let kind: NativeCalendarPopupSectionKind

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

            let items: [NativeCalendarPopupItem]

            if dayEvents.isEmpty {
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
                    kind: kind,
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
                NativeCalendarPopupItem(
                    id: "birthday-\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                    time: formatBirthdayDate(event.startDate, format: config.birthdaysDateFormat),
                    title: birthdayTitle(for: event, showAge: config.birthdaysShowAge)
                )
            }

        return NativeCalendarPopupSection(
            id: "birthdays",
            title: config.birthdaysTitle,
            kind: .birthdays,
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
        guard let open = title.lastIndex(of: "("),
              let close = title.lastIndex(of: ")"),
              open < close else {
            return nil
        }

        let value = title[title.index(after: open)..<close].trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(value)
    }

    private func requestAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            Logger.debug("calendar popup access already granted")

        case .notDetermined:
            guard !didRequestAccess else { return }
            didRequestAccess = true

            eventStore.requestFullAccessToEvents { granted, error in
                if let error {
                    Logger.debug("calendar popup access request failed: \(error)")
                    return
                }

                Logger.debug("calendar popup access granted: \(granted)")
            }

        case .denied, .restricted, .writeOnly:
            Logger.debug("calendar popup access unavailable status=\(status.rawValue)")

        @unknown default:
            Logger.debug("calendar popup access status unknown")
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
