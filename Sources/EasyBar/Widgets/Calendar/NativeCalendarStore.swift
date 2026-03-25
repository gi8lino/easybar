import Foundation
import EasyBarShared

final class NativeCalendarStore: ObservableObject {

    static let shared = NativeCalendarStore()

    @Published private(set) var sections: [NativeCalendarPopupSection] = []

    private init() {}

    func apply(snapshot: CalendarAgentSnapshot) {
        Logger.debug(
            "calendar popup applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) sections=\(snapshot.sections.count)"
        )
        publish(sections: snapshot.sections)
    }

    func clear() {
        Logger.debug("calendar popup cleared")
        publish(sections: [])
    }

    /// Publishes one sections update on the main queue.
    private func publish(sections: [NativeCalendarPopupSection]) {
        DispatchQueue.main.async {
            self.sections = sections
        }
    }
}
