import Foundation
import IOKit.ps

final class PowerEvents {

    static let shared = PowerEvents()

    private var runLoopSource: Unmanaged<CFRunLoopSource>?

    private init() {}

    func subscribePowerSource() {

        let callback: IOPowerSourceCallbackType = { _ in
            EventBus.shared.emit("power_source_change")
        }

        guard let source = IOPSNotificationCreateRunLoopSource(callback, nil) else {
            Logger.debug("failed to create power source run loop source")
            return
        }

        runLoopSource = source

        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            source.takeUnretainedValue(),
            .defaultMode
        )

        Logger.debug("subscribed power_source_change")
    }

    func stopAll() {
        guard let runLoopSource else { return }

        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            runLoopSource.takeUnretainedValue(),
            .defaultMode
        )

        self.runLoopSource = nil
    }
}
