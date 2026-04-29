import EasyBarShared
import Foundation

@MainActor
final class NativeWiFiStore: ObservableObject {
  private static var sharedInstance: NativeWiFiStore?

  static var shared: NativeWiFiStore {
    guard let sharedInstance else {
      fatalError("NativeWiFiStore.bootstrap(logger:) must be called before NativeWiFiStore.shared")
    }

    return sharedInstance
  }

  static func bootstrap(logger: ProcessLogger) {
    sharedInstance = NativeWiFiStore(logger: logger)
  }

  static let didChangeNotification = Notification.Name("easybar.native-wifi-store.did-change")

  @Published private(set) var snapshot: NetworkAgentSnapshot?
  private var lastPublishedSignature: Signature?
  let logger: ProcessLogger

  private struct Signature: Equatable {
    let accessGranted: Bool
    let permissionState: String
    let ssid: String?
    let interfaceName: String?
    let primaryInterfaceIsTunnel: Bool
    let rssi: Int?
  }

  private init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Applies one new snapshot.
  ///
  /// Returns true when the render-relevant state actually changed.
  @discardableResult
  func apply(snapshot: NetworkAgentSnapshot) -> Bool {
    let signature = signature(for: snapshot)
    guard signature != lastPublishedSignature else { return false }

    lastPublishedSignature = signature
    logger.debug(
      "wifi widget applied snapshot",
      "access_granted", "\(snapshot.accessGranted)",
      "permission_state", "\(snapshot.permissionState)",
      "ssid", "\(snapshot.ssid ?? "<none>")",
      "rssi", "\(snapshot.rssi.map(String.init) ?? "<none>")",
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
    logger.debug("wifi widget cleared")
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

  /// Publishes one snapshot change.
  private func publish(snapshot: NetworkAgentSnapshot?) {
    self.snapshot = snapshot
    NotificationCenter.default.post(name: Self.didChangeNotification, object: snapshot)
  }
}
