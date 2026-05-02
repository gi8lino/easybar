import EventKit
import Foundation

/// Stores calendar authorization state safely across EventKit callbacks.
final class CalendarAuthorizationState {
  /// Protects authorization state shared across callbacks.
  private let lock = NSLock()
  /// Last observed EventKit authorization status.
  private var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
  /// Tracks access granted by the current process before EventKit status catches up.
  private var accessGrantedInProcess = false

  /// Stores the latest calendar authorization status.
  func setStatus(_ newStatus: EKAuthorizationStatus) {
    lock.lock()
    status = newStatus

    switch newStatus {
    case .authorized, .fullAccess:
      break
    default:
      accessGrantedInProcess = false
    }

    lock.unlock()
  }

  /// Marks access as granted after an in-process prompt succeeds.
  func markGrantedInProcess() {
    lock.lock()
    accessGrantedInProcess = true
    lock.unlock()
  }

  /// Returns whether calendar access is currently effective.
  func effectiveAccessGranted() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    switch status {
    case .authorized, .fullAccess:
      return true
    default:
      return accessGrantedInProcess
    }
  }

  /// Returns the last known authorization status.
  func currentStatus() -> EKAuthorizationStatus {
    lock.lock()
    defer { lock.unlock() }
    return status
  }

  /// Returns the current permission state as a stable string.
  func permissionState() -> String {
    return describe(currentStatus())
  }

  /// Converts one authorization status into a stable string.
  func describe(_ status: EKAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "not_determined"
    case .restricted:
      return "restricted"
    case .denied:
      return "denied"
    case .authorized:
      return "authorized"
    case .fullAccess:
      return "full_access"
    case .writeOnly:
      return "write_only"
    @unknown default:
      return "unknown"
    }
  }
}
