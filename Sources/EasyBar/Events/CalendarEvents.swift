import Foundation
import EventKit

final class CalendarEvents {

    static let shared = CalendarEvents()

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var didRequestAccess = false
    private let authState = CalendarAuthorizationState.shared

    private init() {}

    func subscribeCalendar() {
        if observer != nil {
            Logger.debug("calendar events already subscribed")
            return
        }

        Logger.info("calendar events subscribe requested")
        let status = EKEventStore.authorizationStatus(for: .event)
        authState.setStatus(status)
        Logger.info("calendar events authorization status before subscribe=\(authState.describe(status))")

        requestAccessIfNeeded()

        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in
            Logger.debug("calendar event store changed")
            EventBus.shared.emit(.calendarChange)
        }

        Logger.debug("subscribed calendar_change")
    }

    func stopAll() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
            Logger.debug("calendar events observer removed")
        }
    }

    private func requestAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authState.setStatus(status)

        Logger.info("calendar access status=\(authState.describe(status))")

        switch status {
        case .fullAccess, .authorized:
            Logger.info("calendar access already granted")

        case .notDetermined:
            guard !didRequestAccess else {
                Logger.debug("calendar access request already attempted")
                return
            }

            didRequestAccess = true
            Logger.info("requesting calendar full access")

            store.requestFullAccessToEvents { granted, error in
                let newStatus = EKEventStore.authorizationStatus(for: .event)
                self.authState.setStatus(newStatus)

                if let error {
                    Logger.error("calendar access request failed status=\(self.authState.describe(newStatus)) error=\(error)")
                    return
                }

                Logger.info("calendar access request completed granted=\(granted) status=\(self.authState.describe(newStatus))")

                guard granted else { return }
                self.authState.markGrantedInProcess()

                DispatchQueue.main.async {
                    EventBus.shared.emit(.calendarChange)
                    NativeCalendarStore.shared.refresh()
                }
            }

        case .denied, .restricted, .writeOnly:
            Logger.warn("calendar access unavailable status=\(authState.describe(status))")

        @unknown default:
            Logger.warn("calendar access status unknown raw=\(status.rawValue)")
        }
    }
}
