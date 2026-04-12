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
    let rssi: Int?
  }

  private init() {}

  /// Applies one new snapshot.
  ///
  /// Returns true when the render-relevant state actually changed.
  @discardableResult
  func apply(snapshot: NetworkAgentSnapshot) -> Bool {
    let signature = signature(for: snapshot)
    guard signature != lastPublishedSignature else { return false }

    lastPublishedSignature = signature
    easybarLog.debug(
      "wifi widget applied snapshot access_granted=\(snapshot.accessGranted) permission_state=\(snapshot.permissionState) ssid=\(snapshot.ssid ?? "<none>") rssi=\(snapshot.rssi.map(String.init) ?? "<none>")"
    )
    publish(snapshot: snapshot)
    return true
  }

  /// Clears the current snapshot.
  ///
  /// Returns true when state was present and got cleared.
  @discardableResult
  func clear() -> Bool {
    guard snapshot != nil else { return false }
    lastPublishedSignature = nil
    easybarLog.debug("wifi widget cleared")
    publish(snapshot: nil)
    return true
  }

  /// Returns the render-relevant snapshot signature.
  private func signature(for snapshot: NetworkAgentSnapshot) -> Signature {
    Signature(
      accessGranted: snapshot.accessGranted,
      permissionState: snapshot.permissionState,
      ssid: snapshot.ssid,
      interfaceName: snapshot.interfaceName,
      primaryInterfaceIsTunnel: snapshot.primaryInterfaceIsTunnel,
      rssi: snapshot.rssi
    )
  }

  /// Publishes one snapshot change on the main queue.
  private func publish(snapshot: NetworkAgentSnapshot?) {
    // NetworkAgentClient already marshals store mutations onto the main queue.
    // Keep this publish synchronous so renders triggered right after apply()
    // observe the fresh snapshot instead of the previous value.
    self.snapshot = snapshot
    NotificationCenter.default.post(name: Self.didChangeNotification, object: snapshot)
  }
}
