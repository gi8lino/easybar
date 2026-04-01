import CoreLocation
import Foundation

final class NetworkLocationAuthorizer: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private let authState = NetworkAgentAuthorizationState()

  private var didRequestAccess = false
  private var onChange: (() -> Void)?

  /// Starts tracking and requesting location authorization when needed.
  func start(onChange: @escaping () -> Void) {
    self.onChange = onChange

    locationManager.delegate = self

    let status = locationManager.authorizationStatus
    authState.setStatus(status)
    AgentLogger.info(
      "network agent authorization status before start=\(authState.permissionState())"
    )

    requestAccessIfNeeded()
  }

  /// Stops authorization callbacks.
  func stop() {
    locationManager.delegate = nil
    onChange = nil
  }

  /// Returns whether location access is currently authorized.
  func isAuthorized() -> Bool {
    authState.isAuthorized()
  }

  /// Returns the current permission label.
  func permissionState() -> String {
    authState.permissionState()
  }

  /// Handles one location authorization change.
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      self.authState.setStatus(status)
      AgentLogger.info(
        "network agent authorization changed status=\(self.authState.permissionState())"
      )
      self.onChange?()
    }
  }

  /// Requests location access when the current state allows it.
  private func requestAccessIfNeeded() {
    let status = locationManager.authorizationStatus
    authState.setStatus(status)
    AgentLogger.info("network agent access status=\(authState.permissionState())")

    switch status {
    case .authorized, .authorizedAlways, .authorizedWhenInUse:
      AgentLogger.info("network agent access already granted")
      onChange?()

    case .notDetermined:
      guard !didRequestAccess else { return }
      didRequestAccess = true

      AgentLogger.info("requesting network when-in-use access")
      locationManager.requestWhenInUseAuthorization()

    case .denied, .restricted:
      AgentLogger.warn("network agent access unavailable status=\(authState.permissionState())")

    @unknown default:
      AgentLogger.warn("network agent access status unknown raw=\(status.rawValue)")
    }
  }
}
