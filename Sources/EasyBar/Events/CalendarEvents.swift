import Foundation
import EventKit

final class CalendarEvents {

    static let shared = CalendarEvents()

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var didRequestAccess = false

    private init() {}

    func subscribeCalendar() {
        if observer != nil {
            Logger.debug("calendar events already subscribed")
            return
        }

        Logger.info("calendar events subscribe requested")
        Logger.info("calendar events authorization status before subscribe=\(describeAuthorizationStatus(EKEventStore.authorizationStatus(for: .event)))")

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

        Logger.info("calendar access status=\(describeAuthorizationStatus(status))")

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

                if let error {
                    Logger.error("calendar access request failed status=\(self.describeAuthorizationStatus(newStatus)) error=\(error)")
                    return
                }

                Logger.info("calendar access request completed granted=\(granted) status=\(self.describeAuthorizationStatus(newStatus))")
            }

        case .denied, .restricted, .writeOnly:
            Logger.warn("calendar access unavailable status=\(describeAuthorizationStatus(status))")

        @unknown default:
            Logger.warn("calendar access status unknown raw=\(status.rawValue)")
        }
    }

    private func describeAuthorizationStatus(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "not_determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorized:
            return "authorized"
        case .fullAccess:
            return "full_access"
        case .writeOnly:
            return "write_only"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }
}
