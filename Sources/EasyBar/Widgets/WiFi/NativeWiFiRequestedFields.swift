import EasyBarShared

/// Shared network-agent field sets used by the native Wi-Fi widget.
enum NativeWiFiRequestedFields {
  /// Fields required to build the native Wi-Fi snapshot model.
  static let snapshot: [NetworkAgentField] = [
    .locationAuthorized,
    .locationPermissionState,
    .generatedAt,
    .ssid,
    .interfaceName,
    .primaryInterfaceIsTunnel,
    .rssi,
  ]
}
