import Foundation
import CoreWLAN
import SystemConfiguration

final class NetworkEvents: NSObject, CWEventDelegate {

    static let shared = NetworkEvents()

    private var reachability: SCNetworkReachability?
    private var wifiClient: CWWiFiClient?

    private override init() {
        super.init()
    }

    /// Subscribes to Wi-Fi SSID changes using CoreWLAN event monitoring.
    func subscribeWifi() {

        let client = CWWiFiClient.shared()
        client.delegate = self

        do {
            try client.startMonitoringEvent(with: .ssidDidChange)
            wifiClient = client
            Logger.debug("subscribed wifi_change")
        } catch {
            Logger.debug("failed to subscribe wifi_change: \(error)")
        }
    }

    /// Subscribes to general network reachability changes.
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
            Logger.debug("failed to create network reachability reference")
            return
        }

        let callback: SCNetworkReachabilityCallBack = { _, _, _ in
            EventBus.shared.emit(.networkChange)
        }

        if !SCNetworkReachabilitySetCallback(reachability, callback, &context) {
            Logger.debug("failed to set network reachability callback")
            return
        }

        if !SCNetworkReachabilitySetDispatchQueue(reachability, DispatchQueue.main) {
            Logger.debug("failed to set network reachability dispatch queue")
            return
        }

        Logger.debug("subscribed network_change")
    }

    func stopAll() {
        if let reachability {
            SCNetworkReachabilitySetDispatchQueue(reachability, nil)
        }

        if let wifiClient {
            do {
                try wifiClient.stopMonitoringAllEvents()
            } catch {
                Logger.debug("failed to stop wifi monitoring: \(error)")
            }
        }

        reachability = nil
        wifiClient = nil
    }

    func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        EventBus.shared.emit(.wifiChange, interfaceName: interfaceName)
    }
}
