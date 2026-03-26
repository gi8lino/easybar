import CoreLocation
import Foundation

final class NetworkAgentAuthorizationState {
  private let lock = NSLock()
  private var status: CLAuthorizationStatus = .notDetermined

  func setStatus(_ newStatus: CLAuthorizationStatus) {
    lock.lock()
    status = newStatus
    lock.unlock()
  }

  func currentStatus() -> CLAuthorizationStatus {
    lock.lock()
    defer { lock.unlock() }
    return status
  }

  func isAuthorized() -> Bool {
    switch currentStatus() {
    case .authorized, .authorizedAlways, .authorizedWhenInUse:
      return true
    default:
      return false
    }
  }

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
