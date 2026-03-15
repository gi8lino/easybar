import Foundation
import EventKit

final class CalendarNativeWidget: NativeWidget {

    let rootID = "builtin_calendar"

    private let store = EKEventStore()

    private var timer: Timer?
    private var eventObserver: NSObjectProtocol?

    func start() {
        CalendarEvents.shared.subscribeCalendar()

        // Update on explicit calendar changes and on time changes.
        eventObserver = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let payload = notification.object as? [String: String],
                let event = payload["event"]
            else {
                return
            }

            if event == "calendar_change" || event == "minute_tick" {
                self?.publish()
            }
        }

        // Keeps "today" fresh even if the event store stays quiet.
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    func stop() {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
            self.eventObserver = nil
        }

        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let formatter = DateFormatter()
        formatter.dateFormat = Config.shared.builtinCalendarFormat

        let node = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: "item",
            parent: nil,
            position: Config.shared.builtinCalendarPosition,
            order: Config.shared.builtinCalendarOrder,
            icon: "🗓",
            text: calendarText(dateFormatter: formatter),
            color: nil,
            visible: true,
            role: nil,
            value: nil,
            min: nil,
            max: nil,
            step: nil,
            values: nil,
            lineWidth: nil,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }

    private func calendarText(dateFormatter: DateFormatter) -> String {
        // Request access lazily too, so the native widget can work standalone.
        store.requestFullAccessToEvents { granted, error in
            if let error {
                Logger.debug("calendar widget access request failed: \(error)")
                return
            }

            Logger.debug("calendar widget access granted: \(granted)")
        }

        let now = Date()
        let calendar = Calendar.current

        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return dateFormatter.string(from: now)
        }

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        guard let nextEvent = events.first else {
            return dateFormatter.string(from: now)
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        return "\(timeFormatter.string(from: nextEvent.startDate)) \(nextEvent.title ?? "Event")"
    }
}
