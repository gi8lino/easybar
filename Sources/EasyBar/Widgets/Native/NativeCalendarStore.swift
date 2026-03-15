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

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d. MMMM yyyy"

        var newSections: [NativeCalendarPopupSection] = []

        for dayOffset in 0..<max(1, config.days) {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                continue
            }

            let dayEvents = events.filter { event in
                event.startDate >= day && event.startDate < nextDay
            }

            guard !dayEvents.isEmpty else { continue }

            let title: String
            if calendar.isDateInToday(day) {
                title = "Today"
            } else if calendar.isDateInTomorrow(day) {
                title = "Tomorrow"
            } else {
                title = dateFormatter.string(from: day)
            }

            let items = dayEvents.map { event in
                NativeCalendarPopupItem(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSince1970)",
                    time: event.isAllDay ? "All day" : timeFormatter.string(from: event.startDate),
                    title: normalizedTitle(event.title)
                )
            }

            newSections.append(
                NativeCalendarPopupSection(
                    id: "section-\(dayOffset)",
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
}
