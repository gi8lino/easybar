import Foundation
import IOKit.ps

final class PowerEvents {

    static let shared = PowerEvents()

    private var runLoopSource: Unmanaged<CFRunLoopSource>?
    private var lastChargingState: Bool?

    private init() {}

    func subscribePowerSource() {
        guard runLoopSource == nil else { return }

        let callback: IOPowerSourceCallbackType = { _ in
            EventBus.shared.emit(.powerSourceChange)
            PowerEvents.shared.handlePowerSourceCallback()
        }

        guard let source = IOPSNotificationCreateRunLoopSource(callback, nil) else {
            Logger.debug("failed to create power source run loop source")
            return
        }

        runLoopSource = source
        lastChargingState = readChargingState()

        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            source.takeUnretainedValue(),
            .defaultMode
        )

        Logger.debug("subscribed power_source_change")
        Logger.debug("subscribed charging_state_change")
    }

    func stopAll() {
        guard let runLoopSource else { return }

        CFRunLoopRemoveSource(
            CFRunLoopGetCurrent(),
            runLoopSource.takeUnretainedValue(),
            .defaultMode
        )

        self.runLoopSource = nil
        self.lastChargingState = nil
    }

    private func handlePowerSourceCallback() {
        let newState = readChargingState()

        if lastChargingState != newState {
            lastChargingState = newState

            EventBus.shared.emit(.chargingStateChange, data: [
                "charging": newState ? "true" : "false"
            ])
        }
    }

    private func readChargingState() -> Bool {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return false
        }

        for source in list {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                (description[kIOPSIsPresentKey as String] as? Bool) == true
            else {
                continue
            }

            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
            let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false

            if powerSourceState == kIOPSACPowerValue {
                return true
            }

            if isCharging {
                return true
            }

            return false
        }

        return false
    }
}
