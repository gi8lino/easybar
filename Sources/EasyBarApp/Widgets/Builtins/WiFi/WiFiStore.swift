import EasyBarShared
import Foundation

@MainActor
final class NativeWiFiStore: ObservableObject {
  static let didChangeNotification = Notification.Name("easybar.native-wifi-store.did-change")

  @Published private(set) var snapshot: NetworkAgentSnapshot?
  private var lastPublishedSignature: NetworkAgentSnapshotRenderSignature?
  let logger: ProcessLogger

  init(logger: ProcessLogger) {
    self.logger = logger
  }

  /// Applies one new snapshot.
  ///
  /// Returns true when the render-relevant state actually changed.
  @discardableResult
  func apply(snapshot: NetworkAgentSnapshot) -> Bool {
    let signature = snapshot.renderSignature
    guard signature != lastPublishedSignature else { return false }

    lastPublishedSignature = signature
    logger.debug(
      "wifi widget applied snapshot",
      .field("access_granted", "\(snapshot.accessGranted)"),
      .field("permission_state", "\(snapshot.permissionState)"),
      .field("ssid_present", "\(snapshot.ssid != nil)"),
      .field("ipv4_present", "\(snapshot.ipv4Address != nil)"),
      .field("ipv6_present", "\(snapshot.ipv6Address != nil)"),
      .field("rssi", "\(snapshot.rssi.map(String.init) ?? "<none>")"),
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

  /// Publishes one snapshot change.
  private func publish(snapshot: NetworkAgentSnapshot?) {
    self.snapshot = snapshot
    NotificationCenter.default.post(name: Self.didChangeNotification, object: snapshot)
  }
}
