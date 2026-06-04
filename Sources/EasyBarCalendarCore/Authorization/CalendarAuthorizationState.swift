import EasyBarShared
import EventKit
import Foundation

/// Stores calendar authorization state safely across EventKit callbacks.
final class CalendarAuthorizationState {
  private struct State {
    var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    var accessGrantedInProcess = false
  }

  /// Last observed EventKit authorization status and in-process grant marker.
  private let state = LockedState(State())

  /// Stores the latest calendar authorization status.
  func setStatus(_ newStatus: EKAuthorizationStatus) {
    state.withLock { state in
      state.status = newStatus

      switch newStatus {
      case .authorized, .fullAccess:
        break
      default:
        state.accessGrantedInProcess = false
      }
    }
  }

  /// Marks access as granted after an in-process prompt succeeds.
  func markGrantedInProcess() {
    state.withLock { state in
      state.accessGrantedInProcess = true
    }
  }

  /// Returns whether calendar access is currently effective.
  func effectiveAccessGranted() -> Bool {
    state.withLock { state in
      switch state.status {
      case .authorized, .fullAccess:
        return true
      default:
        return state.accessGrantedInProcess
      }
    }
  }

  /// Returns the last known authorization status.
  func currentStatus() -> EKAuthorizationStatus {
    state.withLock { $0.status }
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
