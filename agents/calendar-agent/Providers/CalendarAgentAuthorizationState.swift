import EventKit
import Foundation

final class CalendarAgentAuthorizationState {
    private let lock = NSLock()
    private var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private var accessGrantedInProcess = false

    func setStatus(_ newStatus: EKAuthorizationStatus) {
        lock.lock()
        status = newStatus
        lock.unlock()
    }

    func markGrantedInProcess() {
        lock.lock()
        accessGrantedInProcess = true
        lock.unlock()
    }

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

    func currentStatus() -> EKAuthorizationStatus {
        lock.lock()
        defer { lock.unlock() }
        return status
    }

    func permissionState() -> String {
        describe(currentStatus())
    }

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
