import EasyBarShared
import Foundation

final class NativeWiFiStore: ObservableObject {
  static let shared = NativeWiFiStore()
  static let didChangeNotification = Notification.Name("easybar.native-wifi-store.did-change")

  @Published private(set) var snapshot: NetworkAgentSnapshot?
  private var lastPublishedSignature: Signature?

  private struct Signature: Equatable {
    let accessGranted: Bool
    let permissionState: String
    let ssid: String?
    let interfaceName: String?
    let primaryInterfaceIsTunnel: Bool
    let signalBars: Int
    let rssi: Int?
  }

  private init() {}

  func apply(snapshot: NetworkAgentSnapshot) {
    let signature = signature(for: snapshot)
    guard signature != lastPublishedSignature else { return }

    lastPublishedSignature = signature
    Logger.debug(
      "wifi widget applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) ssid=\(snapshot.ssid ?? "<none>") signal_bars=\(snapshot.signalBars)"
    )
    publish(snapshot: snapshot)
  }

  func clear() {
    guard snapshot != nil else { return }
    lastPublishedSignature = nil
    Logger.debug("wifi widget cleared")
    publish(snapshot: nil)
  }

  /// Returns the render-relevant snapshot signature.
  private func signature(for snapshot: NetworkAgentSnapshot) -> Signature {
    Signature(
      accessGranted: snapshot.accessGranted,
      permissionState: snapshot.permissionState,
      ssid: snapshot.ssid,
      interfaceName: snapshot.interfaceName,
      primaryInterfaceIsTunnel: snapshot.primaryInterfaceIsTunnel,
      signalBars: snapshot.signalBars,
      rssi: snapshot.rssi
    )
  }

  /// Publishes one snapshot change on the main queue.
  private func publish(snapshot: NetworkAgentSnapshot?) {
    DispatchQueue.main.async {
      self.snapshot = snapshot
      NotificationCenter.default.post(name: Self.didChangeNotification, object: snapshot)
    }
  }
}
