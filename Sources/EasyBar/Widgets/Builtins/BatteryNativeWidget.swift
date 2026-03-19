import Foundation
import IOKit.ps

/// Native battery widget with configurable colors and hover display modes.
final class BatteryNativeWidget: NativeWidget {

    let rootID = "builtin_battery"

    private var timer: Timer?
    private let eventObserver = EasyBarEventObserver()

    private var isHovered = false

    /// Starts the widget and listens for battery-related events.
    func start() {
        PowerEvents.shared.subscribePowerSource()
        SystemEvents.shared.subscribeSystemWake()

        eventObserver.start { [weak self] payload in
            guard let self else { return }

            if let event = payload.appEvent {
                switch event {
                case .powerSourceChange, .chargingStateChange, .systemWoke:
                    self.publish()
                default:
                    break
                }
                return
            }

            guard let event = payload.widgetEvent else {
                return
            }

            switch event {
            case .mouseEntered:
                guard payload.widgetID == self.rootID else { return }
                self.isHovered = true
                self.publish()

            case .mouseExited:
                guard payload.widgetID == self.rootID else { return }
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

    /// Stops the widget and clears its nodes.
    func stop() {
        eventObserver.stop()

        timer?.invalidate()
        timer = nil
        isHovered = false

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Publishes the current widget tree.
    private func publish() {
        let snapshot = readBatterySnapshot()
        let placement = snapshot.placement
        let style = snapshot.style
        let config = Config.shared.builtinBattery

        let showInlineLabel = shouldShowInlineLabel(
            mode: config.displayMode,
            text: snapshot.text
        )

        let tooltipText = tooltipTextForDisplayMode(
            mode: config.displayMode,
            text: snapshot.text
        )

        let nodes: [WidgetNodeState] = [
            BuiltinNativeNodeFactory.makeRowContainerNode(
                rootID: rootID,
                placement: placement,
                style: style
            ),

            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_icon",
                position: placement.position,
                order: 0,
                icon: snapshot.icon,
                color: snapshot.colorHex,
                fontSize: config.iconSize
            ),

            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_label",
                position: placement.position,
                order: 1,
                text: snapshot.text,
                color: snapshot.colorHex,
                visible: showInlineLabel
            )
        ]

        // Tooltip text is attached to the root node text for the native hover tooltip path.
        let tooltipRoot = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: .row,
            parent: nil,
            position: placement.position,
            order: placement.order,
            icon: "",
            text: tooltipText,
            color: nil,
            iconColor: nil,
            labelColor: nil,
            visible: true,
            role: nil,
            imagePath: nil,
            imageSize: nil,
            imageCornerRadius: nil,
            fontSize: nil,
            iconFontSize: nil,
            labelFontSize: nil,
            value: nil,
            min: nil,
            max: nil,
            step: nil,
            values: nil,
            lineWidth: nil,
            paddingX: style.paddingX,
            paddingY: style.paddingY,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: style.spacing,
            backgroundColor: style.backgroundColorHex,
            borderColor: style.borderColorHex,
            borderWidth: style.borderWidth,
            cornerRadius: style.cornerRadius,
            opacity: style.opacity,
            width: nil,
            height: nil,
            yOffset: nil
        )

        WidgetStore.shared.apply(root: rootID, nodes: [tooltipRoot] + Array(nodes.dropFirst()))
    }

    /// Returns the current battery snapshot.
    private func readBatterySnapshot() -> (
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        icon: String,
        text: String,
        colorHex: String?
    ) {
        let config = Config.shared.builtinBattery
        let placement = config.placement
        let style = config.style

        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return (
                placement,
                style,
                style.icon,
                config.unavailableText,
                resolvedUnavailableColor(config: config)
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
                placement,
                style,
                resolvedBatteryIcon(for: percentage, charging: charging),
                text,
                resolvedBatteryColor(
                    for: percentage,
                    mode: config.colorMode,
                    fixedColorHex: config.fixedColorHex ?? config.style.textColorHex,
                    colors: config.colors
                )
            )
        }

        return (
            placement,
            style,
            style.icon,
            config.unavailableText,
            resolvedUnavailableColor(config: config)
        )
    }

    /// Returns true when the inline label should be shown.
    private func shouldShowInlineLabel(
        mode: Config.BuiltinBatteryDisplayMode,
        text: String
    ) -> Bool {
        guard isHovered, !text.isEmpty else { return false }
        return mode == .expand
    }

    /// Returns tooltip text when tooltip mode is active.
    private func tooltipTextForDisplayMode(
        mode: Config.BuiltinBatteryDisplayMode,
        text: String
    ) -> String {
        guard isHovered, !text.isEmpty else { return "" }
        guard mode == .tooltip else { return "" }
        return text
    }

    /// Resolves the icon for the current battery state.
    private func resolvedBatteryIcon(for percentage: Int, charging: Bool) -> String {
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

    /// Resolves the displayed battery color.
    private func resolvedBatteryColor(
        for percentage: Int,
        mode: Config.BuiltinBatteryColorMode,
        fixedColorHex: String?,
        colors: Config.BuiltinBatteryColors
    ) -> String? {
        if mode == .fixed {
            return fixedColorHex
        }

        switch percentage {
        case 70...100:
            return colors.highColorHex
        case 50...69:
            return colors.mediumColorHex
        case 30...49:
            return colors.lowColorHex
        default:
            return colors.criticalColorHex
        }
    }

    /// Resolves the color used when the battery is unavailable.
    private func resolvedUnavailableColor(config: Config.BatteryBuiltinConfig) -> String? {
        switch config.colorMode {
        case .dynamic:
            return config.style.textColorHex
        case .fixed:
            return config.fixedColorHex ?? config.style.textColorHex
        }
    }
}
