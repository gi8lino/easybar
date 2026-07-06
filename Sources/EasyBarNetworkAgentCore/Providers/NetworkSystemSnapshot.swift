import Foundation

/// Normalized SystemConfiguration network state.
struct NetworkSystemSnapshot {
  /// Empty fallback snapshot used when system state cannot be read.
  static let empty = NetworkSystemSnapshot(
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

  /// Primary network interface name.
  let primaryInterface: String?
  /// First active tunnel interface.
  let activeTunnelInterface: String?
  /// Active tunnel interface names.
  let activeTunnelInterfaces: [String]
  /// Whether the primary interface is a tunnel.
  let primaryInterfaceIsTunnel: Bool
  /// Primary IPv4 address.
  let ipv4Address: String?
  /// Primary IPv6 address.
  let ipv6Address: String?
  /// Default gateway address.
  let defaultGateway: String?
  /// Configured DNS servers.
  let dnsServers: [String]
  /// Whether internet reachability is available.
  let internetReachable: Bool
  /// Whether the network looks captive.
  let captivePortal: Bool
}
