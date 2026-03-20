import EventKit
import Foundation

/// Stores the in-process calendar authorization state.
final class CalendarAuthorizationState {

    static let shared = CalendarAuthorizationState()

    private let lock = NSLock()
    private var status: EKAuthorizationStatus = .notDetermined
    private var accessGrantedInProcess = false

    private init() {}

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

    func currentStatus() -> EKAuthorizationStatus {
        lock.lock()
        defer { lock.unlock() }
        return status
    }

    func effectiveAccessGranted() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        switch status {
        case .fullAccess, .authorized:
            return true
        default:
            return accessGrantedInProcess
        }
    }

    func describeCurrentStatus() -> String {
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
            return "unknown(\(status.rawValue))"
        }
    }
}
