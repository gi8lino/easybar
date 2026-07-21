import EasyBarShared
import XCTest

final class NetworkAgentFieldRegistryTests: XCTestCase {
  func testRegistryCoversEveryNetworkAgentFieldExactlyOnce() {
    let registeredFields = networkAgentFieldRegistry.map(\.field)

    XCTAssertEqual(registeredFields.count, Set(registeredFields).count)
    XCTAssertEqual(Set(registeredFields), Set(NetworkAgentField.allCases))
  }

  func testRegistryDrivesLocationAuthorizationMetadata() {
    XCTAssertTrue(networkAgentFieldRequiresLocationAuthorization(.ssid))
    XCTAssertTrue(networkAgentFieldRequiresLocationAuthorization(.rssi))
    XCTAssertFalse(networkAgentFieldRequiresLocationAuthorization(.ipv4Address))
    XCTAssertFalse(networkAgentFieldRequiresLocationAuthorization(.routeReachable))
    XCTAssertFalse(networkAgentFieldRequiresLocationAuthorization(.locationAuthorized))
  }

  func testFieldAvailabilityMetadataRoundTrips() throws {
    let message = NetworkAgentMessage(
      kind: .fields,
      fields: [NetworkAgentField.routeReachable.rawValue: .bool(true)],
      fieldStatuses: [
        NetworkAgentField.routeReachable.rawValue: .available,
        NetworkAgentField.ssid.rawValue: .permissionDenied,
        NetworkAgentField.captivePortal.rawValue: .unavailable,
      ]
    )

    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(NetworkAgentMessage.self, from: data)

    XCTAssertEqual(decoded.fieldStatuses?[NetworkAgentField.routeReachable.rawValue], .available)
    XCTAssertEqual(decoded.fieldStatuses?[NetworkAgentField.ssid.rawValue], .permissionDenied)
    XCTAssertEqual(decoded.fieldStatuses?[NetworkAgentField.captivePortal.rawValue], .unavailable)
  }
}
