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

  /// Handles bootstrap.
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
    let ipv4Address: String?
    let ipv6Address: String?
    let bssid: String?
    let interfaceName: String?
    let hardwareAddress: String?
    let power: Bool?
    let serviceActive: Bool?
    let primaryInterfaceIsTunnel: Bool
    let rssi: Int?
    let noise: Int?
    let snr: Int?
    let linkQuality: Int?
    let txRate: Int?
    let channel: Int?
    let channelBand: String?
    let channelWidth: String?
    let security: String?
    let phyMode: String?
    let interfaceMode: String?
    let countryCode: String?
    let roaming: Bool?
    let ssidChangedAt: String?
    let interfaceChangedAt: String?
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
      .field("access_granted", "\(snapshot.accessGranted)"),
      .field("permission_state", "\(snapshot.permissionState)"),
      .field("ssid", "\(snapshot.ssid ?? "<none>")"),
      .field("ipv4_address", "\(snapshot.ipv4Address ?? "<none>")"),
      .field("ipv6_address", "\(snapshot.ipv6Address ?? "<none>")"),
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

  /// Returns the render-relevant snapshot signature.
  private func signature(for snapshot: NetworkAgentSnapshot) -> Signature {
    Signature(
      accessGranted: snapshot.accessGranted,
      permissionState: snapshot.permissionState,
      ssid: snapshot.ssid,
      ipv4Address: snapshot.ipv4Address,
      ipv6Address: snapshot.ipv6Address,
      bssid: snapshot.bssid,
      interfaceName: snapshot.interfaceName,
      hardwareAddress: snapshot.hardwareAddress,
      power: snapshot.power,
      serviceActive: snapshot.serviceActive,
      primaryInterfaceIsTunnel: snapshot.primaryInterfaceIsTunnel,
      rssi: snapshot.rssi,
      noise: snapshot.noise,
      snr: snapshot.snr,
      linkQuality: snapshot.linkQuality,
      txRate: snapshot.txRate,
      channel: snapshot.channel,
      channelBand: snapshot.channelBand,
      channelWidth: snapshot.channelWidth,
      security: snapshot.security,
      phyMode: snapshot.phyMode,
      interfaceMode: snapshot.interfaceMode,
      countryCode: snapshot.countryCode,
      roaming: snapshot.roaming,
      ssidChangedAt: snapshot.ssidChangedAt,
      interfaceChangedAt: snapshot.interfaceChangedAt
    )
  }

  /// Publishes one snapshot change.
  private func publish(snapshot: NetworkAgentSnapshot?) {
    self.snapshot = snapshot
    NotificationCenter.default.post(name: Self.didChangeNotification, object: snapshot)
  }
}
