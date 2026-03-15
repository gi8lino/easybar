import Foundation
import IOKit.ps

final class BatteryNativeWidget: NativeWidget {

    let rootID = "builtin_battery"

    private var timer: Timer?
    private var eventObserver: NSObjectProtocol?

    func start() {
        PowerEvents.shared.subscribePowerSource()

        eventObserver = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let payload = notification.object as? [String: String],
                payload["event"] == "power_source_change"
            else {
                return
            }

            self?.publish()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    func stop() {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
            self.eventObserver = nil
        }

        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let snapshot = readBatterySnapshot()
        let node = BuiltinWidgetNodeFactory.makeItemNode(
            rootID: rootID,
            style: snapshot.style,
            text: snapshot.text
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }

    private func readBatterySnapshot() -> (style: Config.BuiltinWidgetStyle, text: String) {
        let config = Config.shared.builtinBattery
        var style = config.style

        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return (style, config.unavailableText)
        }

        for source in list {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                (description[kIOPSIsPresentKey as String] as? Bool) == true
            else {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let max = description[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let charging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false

            let percentage = max > 0 ? Int((Double(current) / Double(max)) * 100.0) : 0

            if charging {
                style.icon = config.chargingIcon
            }

            let text = config.showPercentage ? "\(percentage)%" : ""
            return (style, text)
        }

        return (style, config.unavailableText)
    }
}
