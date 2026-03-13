import AppKit

final class SystemEvents {

    static let shared = SystemEvents()

    private var observers: [NSObjectProtocol] = []

    private init() {}

    func subscribeSystemWake() {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            EventBus.shared.emit("system_woke")
        }

        observers.append(observer)
        Logger.debug("subscribed system_woke")
    }

    func subscribeSleep() {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            EventBus.shared.emit("sleep")
        }

        observers.append(observer)
        Logger.debug("subscribed sleep")
    }

    func subscribeSpaceChange() {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            EventBus.shared.emit("space_change")
        }

        observers.append(observer)
        Logger.debug("subscribed space_change")
    }

    func subscribeAppSwitch() {
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                EventBus.shared.emit("app_switch", data: [
                    "app": app.localizedName ?? ""
                ])
            }
        }

        observers.append(observer)
        Logger.debug("subscribed app_switch")
    }

    func subscribeDisplayChange() {
        let observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            EventBus.shared.emit("display_change")
        }

        observers.append(observer)
        Logger.debug("subscribed display_change")
    }

    func stopAll() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let defaultCenter = NotificationCenter.default

        for observer in observers {
            workspaceCenter.removeObserver(observer)
            defaultCenter.removeObserver(observer)
        }

        observers.removeAll()
    }
}
