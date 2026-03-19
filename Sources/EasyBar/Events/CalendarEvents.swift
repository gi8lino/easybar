import Foundation
import EventKit

final class CalendarEvents {

    static let shared = CalendarEvents()

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var didRequestAccess = false

    private init() {}

    func subscribeCalendar() {
        guard observer == nil else { return }

        requestAccessIfNeeded()

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

    private func requestAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            Logger.debug("calendar access already granted")

        case .notDetermined:
            guard !didRequestAccess else { return }
            didRequestAccess = true

            store.requestFullAccessToEvents { granted, error in
                if let error {
                    Logger.debug("calendar access request failed: \(error)")
                    return
                }

                Logger.debug("calendar access granted: \(granted)")
            }

        case .denied, .restricted, .writeOnly:
            Logger.debug("calendar access unavailable status=\(status.rawValue)")

        @unknown default:
            Logger.debug("calendar access status unknown")
        }
    }
}
