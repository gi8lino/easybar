import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {

    static let shared = LoginItemManager()

    @Published private(set) var isEnabled = false
    @Published private(set) var statusMessage: String?

    private init() {
        refresh()
    }

    func refresh() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp

            switch service.status {
            case .enabled:
                isEnabled = true
                statusMessage = nil

            case .requiresApproval:
                isEnabled = false
                statusMessage = "Login item requires approval in System Settings."

            case .notRegistered:
                isEnabled = false
                statusMessage = nil

            case .notFound:
                isEnabled = false
                statusMessage = "Login item could not be found."

            @unknown default:
                isEnabled = false
                statusMessage = "Unknown login item status."
            }

            Logger.debug("login item status refreshed enabled=\(isEnabled)")
            return
        }

        isEnabled = false
        statusMessage = "Start at login requires macOS 13 or newer."
    }

    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp

            do {
                if enabled {
                    try service.register()
                    Logger.info("start at login enabled")
                } else {
                    try service.unregister()
                    Logger.info("start at login disabled")
                }

                refresh()
            } catch {
                Logger.info("failed to update start at login: \(error)")
                refresh()

                if enabled {
                    statusMessage = "Could not enable start at login."
                } else {
                    statusMessage = "Could not disable start at login."
                }
            }

            return
        }

        isEnabled = false
        statusMessage = "Start at login requires macOS 13 or newer."
    }
}
