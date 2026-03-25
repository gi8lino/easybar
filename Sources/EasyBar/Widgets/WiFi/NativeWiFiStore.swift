import Foundation
import EasyBarShared

final class NativeWiFiStore: ObservableObject {
    static let shared = NativeWiFiStore()
    static let didChangeNotification = Notification.Name("easybar.native-wifi-store.did-change")

    @Published private(set) var snapshot: NetworkAgentSnapshot?

    private init() {}

    func apply(snapshot: NetworkAgentSnapshot) {
        Logger.debug(
            "wifi widget applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) ssid=\(snapshot.ssid ?? "<none>") signal_bars=\(snapshot.signalBars)"
        )
        publish(snapshot: snapshot)
    }

    func clear() {
        Logger.debug("wifi widget cleared")
        publish(snapshot: nil)
    }

    /// Publishes one snapshot change on the main queue.
    private func publish(snapshot: NetworkAgentSnapshot?) {
        DispatchQueue.main.async {
            self.snapshot = snapshot
            NotificationCenter.default.post(name: Self.didChangeNotification, object: snapshot)
        }
    }
}
