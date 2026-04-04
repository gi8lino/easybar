import Foundation
import SystemConfiguration

final class NetworkSystemMonitor {
  private static let watchedNetworkPatterns: [CFString] = [
    "State:/Network/Global/IPv4" as CFString,
    "State:/Network/Global/IPv6" as CFString,
    "State:/Network/Global/DNS" as CFString,
    "State:/Network/Service/.*/IPv4" as CFString,
    "State:/Network/Service/.*/IPv6" as CFString,
  ]

  private var onChange: (() -> Void)?
  private var store: SCDynamicStore?
  private var storeSource: CFRunLoopSource?

  /// Starts listening for primary network interface changes.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    var context = SCDynamicStoreContext(
      version: 0,
      info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
      retain: nil,
      release: nil,
      copyDescription: nil
    )

    guard
      let store = SCDynamicStoreCreate(
        nil,
        "easybar-network-agent" as CFString,
        { _, _, info in
          guard let info else { return }
          let monitor = Unmanaged<NetworkSystemMonitor>.fromOpaque(info).takeUnretainedValue()
          DispatchQueue.main.async {
            monitor.handleNetworkStoreChange()
          }
        },
        &context
      )
    else {
      networkAgentLog.warn("failed to create network dynamic store")
      return
    }

    SCDynamicStoreSetNotificationKeys(store, nil, Self.watchedNetworkPatterns as CFArray)

    guard let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else {
      networkAgentLog.warn("failed to create network dynamic store source")
      return
    }

    self.store = store
    storeSource = source

    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    networkAgentLog.info("network agent subscribed network_change")
  }

  /// Stops network monitoring.
  func stop() {
    if let storeSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), storeSource, .commonModes)
    }

    storeSource = nil
    store = nil
    onChange = nil
  }

  /// Returns the current normalized network state.
  func currentState() -> NetworkSystemSnapshot {
    guard let store else {
      return NetworkSystemSnapshot(
        primaryInterface: nil,
        activeTunnelInterface: nil,
        activeTunnelInterfaces: [],
        primaryInterfaceIsTunnel: false,
        ipv4Address: nil,
        ipv6Address: nil,
        defaultGateway: nil,
        dnsServers: [],
        internetReachable: false,
        captivePortal: false
      )
    }

    guard
      let raw = SCDynamicStoreCopyMultiple(store, nil, Self.watchedNetworkPatterns as CFArray)
        as? [String: Any]
    else {
      return NetworkSystemSnapshot(
        primaryInterface: nil,
        activeTunnelInterface: nil,
        activeTunnelInterfaces: [],
        primaryInterfaceIsTunnel: false,
        ipv4Address: nil,
        ipv6Address: nil,
        defaultGateway: nil,
        dnsServers: [],
        internetReachable: false,
        captivePortal: false
      )
    }

    var allInterfaces: [String] = []
    let globalIPv4 = raw["State:/Network/Global/IPv4"] as? [String: Any]
    let globalIPv6 = raw["State:/Network/Global/IPv6"] as? [String: Any]
    let globalDNS = raw["State:/Network/Global/DNS"] as? [String: Any]

    let primaryInterface =
      normalized(globalIPv4?["PrimaryInterface"] as? String)
      ?? normalized(globalIPv6?["PrimaryInterface"] as? String)

    let primaryServiceID =
      normalized(globalIPv4?["PrimaryService"] as? String)
      ?? normalized(globalIPv6?["PrimaryService"] as? String)

    if let primaryInterface {
      allInterfaces.append(primaryInterface)
    }

    for (key, value) in raw {
      guard key.hasPrefix("State:/Network/Service/") else { continue }
      guard key.hasSuffix("/IPv4") || key.hasSuffix("/IPv6") else { continue }
      guard
        let payload = value as? [String: Any],
        let interfaceName = normalized(payload["InterfaceName"] as? String)
      else {
        continue
      }

      if !allInterfaces.contains(interfaceName) {
        allInterfaces.append(interfaceName)
      }
    }

    let tunnelInterfaces = allInterfaces.filter(isTunnelInterface)
    let primaryInterfaceIsTunnel = primaryInterface.map(isTunnelInterface) ?? false
    let activeTunnelInterface = primaryInterfaceIsTunnel ? primaryInterface : nil
    let primaryIPv4 = primaryServiceID.flatMap {
      raw["State:/Network/Service/\($0)/IPv4"] as? [String: Any]
    }
    let primaryIPv6 = primaryServiceID.flatMap {
      raw["State:/Network/Service/\($0)/IPv6"] as? [String: Any]
    }

    let ipv4Address = firstString(in: primaryIPv4?["Addresses"])
    let ipv6Address = firstString(in: primaryIPv6?["Addresses"])
    let defaultGateway =
      normalized(globalIPv4?["Router"] as? String)
      ?? normalized(primaryIPv4?["Router"] as? String)
    let dnsServers = stringArray(in: globalDNS?["ServerAddresses"])
    let internetReachable = isInternetReachable()
    let captivePortal = !internetReachable && ipv4Address != nil && defaultGateway != nil

    return NetworkSystemSnapshot(
      primaryInterface: primaryInterface,
      activeTunnelInterface: activeTunnelInterface,
      activeTunnelInterfaces: tunnelInterfaces,
      primaryInterfaceIsTunnel: primaryInterfaceIsTunnel,
      ipv4Address: ipv4Address,
      ipv6Address: ipv6Address,
      defaultGateway: defaultGateway,
      dnsServers: dnsServers,
      internetReachable: internetReachable,
      captivePortal: captivePortal
    )
  }

  /// Handles one dynamic store change callback.
  private func handleNetworkStoreChange() {
    networkAgentLog.info("network agent dynamic store changed")
    onChange?()
  }

  /// Returns whether one interface name represents a tunnel.
  private func isTunnelInterface(_ name: String) -> Bool {
    name.hasPrefix("utun")
      || name.hasPrefix("ppp")
      || name.hasPrefix("ipsec")
      || name.hasPrefix("tap")
      || name.hasPrefix("tun")
  }

  /// Returns whether the network looks internet-reachable.
  private func isInternetReachable() -> Bool {
    guard let reachability = SCNetworkReachabilityCreateWithName(nil, "1.1.1.1") else {
      return false
    }

    var flags = SCNetworkReachabilityFlags()
    guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
      return false
    }

    return flags.contains(.reachable) && !flags.contains(.connectionRequired)
  }

  /// Returns the first trimmed string from an array-like value.
  private func firstString(in value: Any?) -> String? {
    guard let values = value as? [String] else { return nil }
    return values.first.flatMap(normalized)
  }

  /// Returns a cleaned string array from an array-like value.
  private func stringArray(in value: Any?) -> [String] {
    guard let values = value as? [String] else { return [] }
    return values.compactMap(normalized)
  }

  /// Trims one optional string and drops empty values.
  private func normalized(_ value: String?) -> String? {
    guard let value else { return nil }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
