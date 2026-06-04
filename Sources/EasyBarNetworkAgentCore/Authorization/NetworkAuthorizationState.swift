import CoreLocation
import EasyBarShared
import Foundation

/// Stores the current CoreLocation authorization status for the network agent.
final class NetworkAuthorizationState {
  private let state = LockedState(CLAuthorizationStatus.notDetermined)

  /// Creates one authorization state wrapper.
  init() {}

  /// Stores the latest location authorization status.
  func setStatus(_ newStatus: CLAuthorizationStatus) {
    state.withLock { status in
      status = newStatus
    }
  }

  /// Returns the last known authorization status.
  func currentStatus() -> CLAuthorizationStatus {
    state.withLock { $0 }
  }

  /// Returns whether Wi-Fi access is currently authorized.
  func isAuthorized() -> Bool {
    switch currentStatus() {
    case .authorized, .authorizedAlways, .authorizedWhenInUse:
      return true
    default:
      return false
    }
  }

  /// Returns the current permission state as a stable string.
  func permissionState() -> String {
    switch currentStatus() {
    case .notDetermined:
      return "not_determined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    case .authorizedAlways:
      return "authorized_always"
    case .authorizedWhenInUse:
      return "authorized_when_in_use"
    @unknown default:
      return "unknown"
    }
  }
}
