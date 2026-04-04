import CoreLocation
import Foundation

/// Stores the current CoreLocation authorization status for network agents.
public final class NetworkAgentAuthorizationState {
  private let lock = NSLock()
  private var status: CLAuthorizationStatus = .notDetermined

  /// Creates one authorization state wrapper.
  public init() {}

  /// Stores the latest location authorization status.
  public func setStatus(_ newStatus: CLAuthorizationStatus) {
    lock.lock()
    status = newStatus
    lock.unlock()
  }

  /// Returns the last known authorization status.
  public func currentStatus() -> CLAuthorizationStatus {
    lock.lock()
    defer { lock.unlock() }
    return status
  }

  /// Returns whether Wi-Fi access is currently authorized.
  public func isAuthorized() -> Bool {
    switch currentStatus() {
    case .authorized, .authorizedAlways, .authorizedWhenInUse:
      return true
    default:
      return false
    }
  }

  /// Returns the current permission state as a stable string.
  public func permissionState() -> String {
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
