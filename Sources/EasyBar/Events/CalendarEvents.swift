import Foundation
import EventKit

final class CalendarEvents {

    static let shared = CalendarEvents()

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?

    private init() {}

    func subscribeCalendar() {
        guard observer == nil else { return }

        // Request once; notification still works after access is granted.
        store.requestFullAccessToEvents { granted, error in
            if let error {
                Logger.debug("calendar access request failed: \(error)")
                return
            }

            Logger.debug("calendar access granted: \(granted)")
        }

        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            EventBus.shared.emit(.calendarChange)
        }

        Logger.debug("subscribed calendar_change")
    }

    func stopAll() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
