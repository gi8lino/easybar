import CoreWLAN
import Foundation
import SystemConfiguration

final class NetworkEvents: NSObject, CWEventDelegate {

  static let shared = NetworkEvents()

  private var reachability: SCNetworkReachability?
  private var wifiClient: CWWiFiClient?

  private override init() {
    super.init()
  }

  /// Starts Wi-Fi SSID change observation.
  func subscribeWifi() {
    let client = CWWiFiClient.shared()
    client.delegate = self

    do {
      try client.startMonitoringEvent(with: .ssidDidChange)
      wifiClient = client
      easybarLog.debug("subscribed wifi_change")
    } catch {
      easybarLog.debug("failed to subscribe wifi_change: \(error)")
    }
  }

  /// Starts general network reachability observation.
  func subscribeNetwork() {
    var context = SCNetworkReachabilityContext(
      version: 0,
      info: nil,
      retain: nil,
      release: nil,
      copyDescription: nil
    )

    reachability = SCNetworkReachabilityCreateWithName(nil, "apple.com")

    guard let reachability else {
      easybarLog.debug("failed to create network reachability reference")
      return
    }

    let callback: SCNetworkReachabilityCallBack = { _, _, _ in
      EventBus.shared.emit(.networkChange)
    }

    guard SCNetworkReachabilitySetCallback(reachability, callback, &context) else {
      easybarLog.debug("failed to set network reachability callback")
      return
    }

    guard SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.main) else {
      easybarLog.debug("failed to set network reachability dispatch queue")
      return
    }

    easybarLog.debug("subscribed network_change")
  }

  /// Stops Wi-Fi and network reachability observation.
  func stopAll() {
    if let reachability {
      SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }

    if let wifiClient {
      do {
        try wifiClient.stopMonitoringAllEvents()
      } catch {
        easybarLog.debug("failed to stop wifi monitoring: \(error)")
      }
    }

    reachability = nil
    wifiClient = nil
  }

  /// Handles CoreWLAN SSID change callbacks.
  func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
    EventBus.shared.emit(.wifiChange, interfaceName: interfaceName)
  }
}
