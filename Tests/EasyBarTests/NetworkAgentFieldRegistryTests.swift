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
    XCTAssertFalse(networkAgentFieldRequiresLocationAuthorization(.locationAuthorized))
  }
}
