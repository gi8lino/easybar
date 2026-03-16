import Foundation
import IOKit.ps

final class BatteryNativeWidget: NativeWidget {

    let rootID = "builtin_battery"

    private var timer: Timer?
    private var eventObserver: NSObjectProtocol?

    private var isHovered = false

    func start() {
        PowerEvents.shared.subscribePowerSource()
        SystemEvents.shared.subscribeSystemWake()

        eventObserver = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self,
                let payload = notification.object as? [String: String],
                let event = payload["event"]
            else {
                return
            }

            switch event {
            case "power_source_change", "charging_state_change", "system_woke":
                self.publish()

            case "mouse.entered":
                guard payload["widget"] == self.rootID else { return }
                self.isHovered = true
                self.publish()

            case "mouse.exited":
                guard payload["widget"] == self.rootID else { return }
                self.isHovered = false
                self.publish()

            default:
                break
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
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
        isHovered = false

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let snapshot = readBatterySnapshot()
        let style = snapshot.style

        let nodes: [WidgetNodeState] = [
            WidgetNodeState(
                id: rootID,
                root: rootID,
                kind: "row",
                parent: nil,
                position: style.position,
                order: style.order,
                icon: "",
                text: "",
                color: nil,
                visible: true,
                role: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: style.paddingX,
                paddingY: style.paddingY,
                spacing: style.spacing,
                backgroundColor: style.backgroundColorHex,
                borderColor: style.borderColorHex,
                borderWidth: style.borderWidth,
                cornerRadius: style.cornerRadius,
                opacity: style.opacity
            ),

            WidgetNodeState(
                id: "\(rootID)_icon",
                root: rootID,
                kind: "item",
                parent: rootID,
                position: style.position,
                order: 0,
                icon: snapshot.icon,
                text: "",
                color: snapshot.colorHex,
                visible: true,
                role: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: 0,
                paddingY: 0,
                spacing: 4,
                backgroundColor: nil,
                borderColor: nil,
                borderWidth: nil,
                cornerRadius: nil,
                opacity: 1
            ),

            WidgetNodeState(
                id: "\(rootID)_label",
                root: rootID,
                kind: "item",
                parent: rootID,
                position: style.position,
                order: 1,
                icon: "",
                text: snapshot.text,
                color: snapshot.colorHex,
                visible: isHovered && !snapshot.text.isEmpty,
                role: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: 0,
                paddingY: 0,
                spacing: 4,
                backgroundColor: nil,
                borderColor: nil,
                borderWidth: nil,
                cornerRadius: nil,
                opacity: 1
            )
        ]

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
    }

    private func readBatterySnapshot() -> (
        style: Config.BuiltinWidgetStyle,
        icon: String,
        text: String,
        colorHex: String?
    ) {
        let config = Config.shared.builtinBattery
        let style = config.style

        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return (
                style,
                // Use configured fallback icon if state cannot be read.
                style.icon,
                config.unavailableText,
                config.style.textColorHex
            )
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
            let percentage = max > 0 ? Int((Double(current) / Double(max)) * 100.0) : 0

            let powerSourceState = description[kIOPSPowerSourceStateKey as String] as? String
            let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
            let charging = powerSourceState == kIOPSACPowerValue || isCharging

            let text = config.showPercentage ? "\(percentage)%" : ""

            return (
                style,
                resolvedBatteryIcon(for: percentage, charging: charging, fallback: style.icon),
                text,
                resolvedBatteryColor(for: percentage, charging: charging, fallback: config.style.textColorHex)
            )
        }

        return (
            style,
            style.icon,
            config.unavailableText,
            config.style.textColorHex
        )
    }

    private func resolvedBatteryIcon(
        for percentage: Int,
        charging: Bool,
        fallback: String
    ) -> String {
        if percentage <= 0 && !fallback.isEmpty {
            return fallback
        }

        if charging {
            switch percentage {
            case 100:      return "󰂅"
            case 90...99:  return "󰂋"
            case 80...89:  return "󰂊"
            case 70...79:  return "󰢞"
            case 60...69:  return "󰂉"
            case 50...59:  return "󰢝"
            case 40...49:  return "󰂈"
            case 30...39:  return "󰂇"
            case 20...29:  return "󰂆"
            case 10...19:  return "󰢜"
            default:       return "󰂃"
            }
        }

        switch percentage {
        case 100:      return "󰁹"
        case 90...99:  return "󰂂"
        case 80...89:  return "󰂁"
        case 70...79:  return "󰂀"
        case 60...69:  return "󰁿"
        case 50...59:  return "󰁾"
        case 40...49:  return "󰁽"
        case 30...39:  return "󰁼"
        case 20...29:  return "󰁻"
        case 10...19:  return "󰁺"
        default:       return "󰂃"
        }
    }

    private func resolvedBatteryColor(
        for percentage: Int,
        charging: Bool,
        fallback: String?
    ) -> String? {
        // Explicit text_color wins.
        if let fallback, !fallback.isEmpty {
            return fallback
        }

        if charging {
            switch percentage {
            case 70...100:
                return "#8bd5ca"
            case 50...69:
                return "#eed49f"
            case 30...49:
                return "#f5a97f"
            default:
                return "#ed8796"
            }
        }

        switch percentage {
        case 70...100:
            return "#8bd5ca"
        case 50...69:
            return "#eed49f"
        case 30...49:
            return "#f5a97f"
        default:
            return "#ed8796"
        }
    }
}
