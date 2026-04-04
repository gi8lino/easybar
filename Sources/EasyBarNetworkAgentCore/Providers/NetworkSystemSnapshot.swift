import Foundation

struct NetworkSystemSnapshot {
  let primaryInterface: String?
  let activeTunnelInterface: String?
  let activeTunnelInterfaces: [String]
  let primaryInterfaceIsTunnel: Bool
  let ipv4Address: String?
  let ipv6Address: String?
  let defaultGateway: String?
  let dnsServers: [String]
  let internetReachable: Bool
  let captivePortal: Bool
}
