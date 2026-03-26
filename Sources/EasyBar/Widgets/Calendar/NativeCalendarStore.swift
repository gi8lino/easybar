import Foundation
import EasyBarShared

final class NativeCalendarStore: ObservableObject {

    static let shared = NativeCalendarStore()

    @Published private(set) var snapshot: CalendarAgentSnapshot?
    @Published private(set) var sections: [NativeCalendarPopupSection] = []

    private init() {}

    func apply(snapshot: CalendarAgentSnapshot) {
        Logger.debug(
            "calendar popup applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) sections=\(snapshot.sections.count)"
        )
        publish(snapshot: snapshot)
    }

    func clear() {
        Logger.debug("calendar popup cleared")
        publish(snapshot: nil)
    }

    /// Publishes one calendar snapshot update on the main queue.
    private func publish(snapshot: CalendarAgentSnapshot?) {
        DispatchQueue.main.async {
            self.snapshot = snapshot
            self.sections = snapshot?.sections ?? []
        }
    }
}
