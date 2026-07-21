import CoreLocation
import CoreWLAN
import EasyBarShared
import XCTest

@testable import EasyBarNetworkAgentCore

@MainActor
final class NetworkAgentCoreRegressionTests: XCTestCase {
  func testPartialCoreWLANRegistrationRollsBackAllEvents() {
    let client = FakeWiFiClient(failRegistrationAt: 3)
    let monitor = NetworkWiFiMonitor(
      componentName: "network-test",
      logger: ProcessLogger(label: "network-test", minimumLevel: .error),
      makeClient: { client }
    )

    monitor.start {}

    XCTAssertEqual(client.registrationCalls, 3)
    XCTAssertEqual(client.stopCalls, 1)
    XCTAssertNil(client.delegate)

    client.failRegistrationAt = nil
    monitor.start {}

    XCTAssertEqual(client.registrationCalls, 11)
    XCTAssertEqual(client.stopCalls, 1)

    monitor.stop()
    XCTAssertEqual(client.stopCalls, 2)
    XCTAssertNil(client.delegate)
  }

  func testRepeatedWiFiMonitorStartKeepsOneRegistrationSetAndLatestCallback() async {
    let client = FakeWiFiClient()
    let monitor = NetworkWiFiMonitor(
      componentName: "network-test",
      logger: ProcessLogger(label: "network-test", minimumLevel: .error),
      makeClient: { client }
    )
    var firstCallbackCount = 0
    var secondCallbackCount = 0
    let callback = expectation(description: "latest callback")

    monitor.start {
      firstCallbackCount += 1
    }
    monitor.start {
      secondCallbackCount += 1
      callback.fulfill()
    }

    XCTAssertEqual(client.registrationCalls, 8)

    monitor.ssidDidChangeForWiFiInterface(withName: "en0")
    await fulfillment(of: [callback], timeout: 1)

    XCTAssertEqual(firstCallbackCount, 0)
    XCTAssertEqual(secondCallbackCount, 1)
    XCTAssertEqual(client.registrationCalls, 8)

    monitor.stop()
  }

  func testCurrentWiFiStateReadIsSideEffectFree() {
    let client = FakeWiFiClient()
    let monitor = NetworkWiFiMonitor(
      componentName: "network-test",
      logger: ProcessLogger(label: "network-test", minimumLevel: .error),
      makeClient: { client }
    )

    monitor.start {}
    let first = monitor.currentState()
    let second = monitor.currentState()

    XCTAssertEqual(first, second)
    monitor.stop()
  }

  func testRouteAssessmentDoesNotInferCaptivePortalFromOfflineLAN() {
    let offlineLAN = NetworkRouteAssessment.make(
      routeReachable: false,
      hasLocalAddress: true
    )
    XCTAssertFalse(offlineLAN.routeReachable)
    XCTAssertTrue(offlineLAN.routeUnavailableWithLocalAddress)
    XCTAssertNil(offlineLAN.captivePortal)

    let routeOnly = NetworkRouteAssessment.make(
      routeReachable: true,
      hasLocalAddress: true
    )
    XCTAssertTrue(routeOnly.routeReachable)
    XCTAssertFalse(routeOnly.routeUnavailableWithLocalAddress)
    XCTAssertNil(routeOnly.captivePortal)

    let confirmedCaptive = NetworkRouteAssessment.make(
      routeReachable: true,
      hasLocalAddress: true,
      confirmedCaptivePortal: true
    )
    XCTAssertEqual(confirmedCaptive.captivePortal, true)

    let ipv6Only = NetworkRouteAssessment.make(
      routeReachable: false,
      hasLocalAddress: true
    )
    XCTAssertTrue(ipv6Only.routeUnavailableWithLocalAddress)
  }

  func testIPv6SelectionPrefersGlobalThenUniqueLocalThenScopedLinkLocal() {
    XCTAssertEqual(
      NetworkAddressSelection.preferredIPv6(
        from: ["fe80::1", "fd00::1", "2001:db8::1"],
        scopeInterface: "en0"
      ),
      "2001:db8::1"
    )
    XCTAssertEqual(
      NetworkAddressSelection.preferredIPv6(
        from: ["fe80::1", "fd00::1"],
        scopeInterface: "en0"
      ),
      "fd00::1"
    )
    XCTAssertEqual(
      NetworkAddressSelection.preferredIPv6(
        from: ["invalid", "fe80::1"],
        scopeInterface: "en0"
      ),
      "fe80::1%en0"
    )
    XCTAssertNil(
      NetworkAddressSelection.preferredIPv6(
        from: ["::1", "ff02::1"],
        scopeInterface: "en0"
      )
    )
  }

  func testAddresslessTunnelNamesAreDiscoveredFromInterfaceInventory() {
    XCTAssertEqual(
      NetworkInterfaceDiscovery.tunnelInterfaces(
        from: ["en0", "utun4", "lo0", "ppp0", "utun4"]
      ),
      ["ppp0", "utun4"]
    )
  }

  func testCoreWLANNormalizationUsesStableRawValueMappings() {
    XCTAssertEqual(NetworkWiFiNormalization.channelBand(rawValue: 1), "2.4ghz")
    XCTAssertEqual(NetworkWiFiNormalization.channelBand(rawValue: 3), "6ghz")
    XCTAssertEqual(NetworkWiFiNormalization.channelBand(rawValue: 999), "unknown")

    XCTAssertEqual(NetworkWiFiNormalization.channelWidth(rawValue: 4), "160mhz")
    XCTAssertEqual(NetworkWiFiNormalization.security(rawValue: 12), "wpa3_enterprise")
    XCTAssertEqual(NetworkWiFiNormalization.security(rawValue: 13), "wpa3_transition")
    XCTAssertEqual(NetworkWiFiNormalization.phyMode(rawValue: 7), "802.11be")
    XCTAssertEqual(NetworkWiFiNormalization.interfaceMode(rawValue: 3), "hostap")
  }

  func testTransmitRateRejectsNonFiniteAndOutOfRangeValues() {
    XCTAssertNil(NetworkWiFiNormalization.transmitRate(.nan))
    XCTAssertNil(NetworkWiFiNormalization.transmitRate(.infinity))
    XCTAssertNil(NetworkWiFiNormalization.transmitRate(-1))
    XCTAssertNil(NetworkWiFiNormalization.transmitRate(Double.greatestFiniteMagnitude))
    XCTAssertEqual(NetworkWiFiNormalization.transmitRate(866.7), 867)
  }

  func testProviderSamplesAuthorizationOncePerResponse() {
    let probe = NetworkProviderProbe()
    probe.authorization = NetworkAuthorizationSnapshot(status: .authorized)
    let provider = makeProvider(probe: probe)

    let snapshot = provider.snapshot()

    XCTAssertEqual(probe.authorizationSamples, 1)
    XCTAssertTrue(snapshot.accessGranted)
    XCTAssertEqual(snapshot.permissionState, "authorized")

    _ = provider.responseFields(
      for: [.locationAuthorized, .locationPermissionState, .routeReachable],
      allowUnauthorizedFieldsWithoutLocation: false
    )
    XCTAssertEqual(probe.authorizationSamples, 2)
  }

  func testPartialUnauthorizedResponseMarksEveryRequestedField() {
    let probe = NetworkProviderProbe()
    probe.authorization = NetworkAuthorizationSnapshot(status: .denied)
    let provider = makeProvider(probe: probe)

    let response = provider.responseFields(
      for: [.ssid, .routeReachable, .captivePortal],
      allowUnauthorizedFieldsWithoutLocation: true
    )

    XCTAssertNil(response.errorCode)
    XCTAssertEqual(response.statuses?[NetworkAgentField.ssid.rawValue], .permissionDenied)
    XCTAssertEqual(response.statuses?[NetworkAgentField.routeReachable.rawValue], .available)
    XCTAssertEqual(response.statuses?[NetworkAgentField.captivePortal.rawValue], .unavailable)
    XCTAssertEqual(
      response.values?[NetworkAgentField.routeReachable.rawValue],
      .bool(true)
    )
    XCTAssertNil(response.values?[NetworkAgentField.ssid.rawValue])
  }

  func testRepeatedProviderStartKeepsOneMonitorSet() {
    let probe = NetworkProviderProbe()
    let provider = makeProvider(probe: probe)
    var firstNotifications = 0
    var secondNotifications = 0

    provider.start { firstNotifications += 1 }
    provider.start { secondNotifications += 1 }

    XCTAssertEqual(probe.authorizationStarts, 1)
    XCTAssertEqual(probe.wifiStarts, 1)
    XCTAssertEqual(probe.systemStarts, 1)
    XCTAssertEqual(firstNotifications, 1)
    XCTAssertEqual(secondNotifications, 1)

    provider.stop()
    XCTAssertEqual(probe.authorizationStops, 1)
    XCTAssertEqual(probe.wifiStops, 1)
    XCTAssertEqual(probe.systemStops, 1)
  }

  private func makeProvider(probe: NetworkProviderProbe) -> NetworkSnapshotProvider {
    NetworkSnapshotProvider(
      componentName: "network-test",
      refreshIntervalSeconds: 0,
      logger: ProcessLogger(label: "network-test", minimumLevel: .error),
      dependencies: NetworkSnapshotProviderDependencies(
        startAuthorization: { callback in
          probe.authorizationStarts += 1
          probe.authorizationCallback = callback
        },
        stopAuthorization: { probe.authorizationStops += 1 },
        authorizationSnapshot: {
          probe.authorizationSamples += 1
          return probe.authorization
        },
        startWiFi: { callback in
          probe.wifiStarts += 1
          probe.wifiCallback = callback
        },
        stopWiFi: { probe.wifiStops += 1 },
        refreshWiFi: { _ in probe.wifiRefreshes += 1 },
        currentWiFi: { probe.wifi },
        startSystem: { callback in
          probe.systemStarts += 1
          probe.systemCallback = callback
        },
        stopSystem: { probe.systemStops += 1 },
        currentSystem: { probe.system }
      )
    )
  }
}

@MainActor
private final class FakeWiFiClient: NetworkWiFiClientAdapter {
  enum Failure: Error {
    case registration
    case stop
  }

  var delegate: CWEventDelegate?
  var failRegistrationAt: Int?
  var failStop = false
  private(set) var registrationCalls = 0
  private(set) var stopCalls = 0

  init(failRegistrationAt: Int? = nil) {
    self.failRegistrationAt = failRegistrationAt
  }

  func startMonitoringEvent(with eventType: CWEventType) throws {
    registrationCalls += 1
    if let failRegistrationAt, registrationCalls == failRegistrationAt {
      throw Failure.registration
    }
  }

  func stopMonitoringAllEvents() throws {
    stopCalls += 1
    if failStop {
      throw Failure.stop
    }
  }

  func interface() -> CWInterface? {
    nil
  }
}

@MainActor
private final class NetworkProviderProbe {
  var authorization = NetworkAuthorizationSnapshot(status: .notDetermined)
  var wifi = NetworkWiFiSnapshot.empty
  var system = NetworkSystemSnapshot(
    primaryInterface: "en0",
    activeTunnelInterface: nil,
    activeTunnelInterfaces: [],
    primaryInterfaceIsTunnel: false,
    ipv4Address: "192.0.2.2",
    ipv6Address: "2001:db8::2",
    defaultGateway: "192.0.2.1",
    dnsServers: ["192.0.2.53"],
    routeReachable: true,
    routeUnavailableWithLocalAddress: false,
    captivePortal: nil
  )

  var authorizationStarts = 0
  var authorizationStops = 0
  var authorizationSamples = 0
  var wifiStarts = 0
  var wifiStops = 0
  var wifiRefreshes = 0
  var systemStarts = 0
  var systemStops = 0
  var authorizationCallback: (() -> Void)?
  var wifiCallback: (() -> Void)?
  var systemCallback: (() -> Void)?
}
