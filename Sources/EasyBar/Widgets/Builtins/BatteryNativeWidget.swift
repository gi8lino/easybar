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

            if self.handleAppEvent(payload) {
                return
            }

            self.handleWidgetEvent(payload)
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
        let config = Config.shared.builtinBattery

        WidgetStore.shared.apply(root: rootID, nodes: makeNodes(snapshot: snapshot, config: config))
    }

    /// Builds the normal inline battery layout.
    private func makeInlineNodes(
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        text: String,
        icon: String,
        colorHex: String?,
        showInlineLabel: Bool
    ) -> [WidgetNodeState] {
        let config = Config.shared.builtinBattery

        return [
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
                icon: icon,
                color: colorHex,
                fontSize: config.iconSize
            ),

            inlineLabelNode(
                placement: placement,
                text: text,
                colorHex: colorHex,
                showInlineLabel: showInlineLabel
            )
        ]
    }

    /// Builds the hover popup layout used for `display_mode = "tooltip"`.
    private func makeTooltipPopupNodes(
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        icon: String,
        text: String,
        colorHex: String?
    ) -> [WidgetNodeState] {
        let config = Config.shared.builtinBattery
        let popup = config.popup

        let root = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: .popup,
            parent: placement.groupID,
            position: placement.position,
            order: placement.order,
            icon: "",
            text: "",
            color: nil,
            iconColor: nil,
            labelColor: nil,
            visible: true,
            role: nil,
            receivesMouseHover: nil,
            receivesMouseClick: nil,
            receivesMouseScroll: nil,
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
            marginX: style.marginX,
            marginY: style.marginY,
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

        let anchorRow = WidgetNodeState(
            id: "\(rootID)_anchor",
            root: rootID,
            kind: .row,
            parent: rootID,
            position: placement.position,
            order: 0,
            icon: "",
            text: "",
            color: nil,
            iconColor: nil,
            labelColor: nil,
            visible: true,
            role: .popupAnchor,
            receivesMouseHover: nil,
            receivesMouseClick: nil,
            receivesMouseScroll: nil,
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
            paddingX: 0,
            paddingY: 0,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: style.spacing,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1,
            width: nil,
            height: nil,
            yOffset: nil
        )

        let anchorIcon = BuiltinNativeNodeFactory.makeChildItemNode(
            rootID: rootID,
            parentID: "\(rootID)_anchor",
            childID: "\(rootID)_icon",
            position: placement.position,
            order: 0,
            icon: icon,
            color: colorHex,
            fontSize: config.iconSize
        )

        let popupColumn = WidgetNodeState(
            id: "\(rootID)_popup",
            root: rootID,
            kind: .column,
            parent: rootID,
            position: placement.position,
            order: 0,
            icon: "",
            text: "",
            color: nil,
            iconColor: nil,
            labelColor: nil,
            visible: !text.isEmpty,
            role: nil,
            receivesMouseHover: nil,
            receivesMouseClick: nil,
            receivesMouseScroll: nil,
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
            paddingX: popup.paddingX,
            paddingY: popup.paddingY,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: 4,
            backgroundColor: popup.backgroundColorHex,
            borderColor: popup.borderColorHex,
            borderWidth: popup.borderWidth,
            cornerRadius: popup.cornerRadius,
            opacity: 1,
            width: nil,
            height: nil,
            yOffset: nil
        )

        let popupText = BuiltinNativeNodeFactory.makeChildItemNode(
            rootID: rootID,
            parentID: "\(rootID)_popup",
            childID: "\(rootID)_popup_text",
            position: placement.position,
            order: 0,
            text: text,
            color: resolvedPopupTextColor(
                popupTextColorHex: popup.textColorHex,
                fallbackColorHex: colorHex,
                styleTextColorHex: style.textColorHex
            ),
            visible: !text.isEmpty
        )

        let popupSpacer = WidgetNodeState(
            id: "\(rootID)_popup_spacer",
            root: rootID,
            kind: .item,
            parent: rootID,
            position: placement.position,
            order: 1,
            icon: "",
            text: "",
            color: nil,
            iconColor: nil,
            labelColor: nil,
            visible: false,
            role: nil,
            receivesMouseHover: nil,
            receivesMouseClick: nil,
            receivesMouseScroll: nil,
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
            paddingX: popup.marginX,
            paddingY: popup.marginY,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: nil,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1,
            width: nil,
            height: nil,
            yOffset: nil
        )

        return [
            root,
            anchorRow,
            anchorIcon,
            popupSpacer,
            popupColumn,
            popupText
        ]
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
            return unavailableSnapshot(
                placement: placement,
                style: style,
                config: config
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

        return unavailableSnapshot(
            placement: placement,
            style: style,
            config: config
        )
    }

    private func handleAppEvent(_ payload: EasyBarEventPayload) -> Bool {
        guard let event = payload.appEvent else {
            return false
        }

        guard event == .powerSourceChange || event == .chargingStateChange || event == .systemWoke else {
            return false
        }

        publish()
        return true
    }

    private func handleWidgetEvent(_ payload: EasyBarEventPayload) {
        guard let event = payload.widgetEvent else { return }
        guard payload.widgetID == rootID else { return }

        switch event {
        case .mouseEntered:
            guard !isHovered else { return }
            isHovered = true
            publishIfHoverAffectsLayout()

        case .mouseExited:
            guard isHovered else { return }
            isHovered = false
            publishIfHoverAffectsLayout()

        default:
            break
        }
    }

    private func makeNodes(
        snapshot: (
            placement: Config.BuiltinWidgetPlacement,
            style: Config.BuiltinWidgetStyle,
            icon: String,
            text: String,
            colorHex: String?
        ),
        config: Config.BatteryBuiltinConfig
    ) -> [WidgetNodeState] {
        guard config.displayMode != .tooltip else {
            return makeTooltipPopupNodes(
                placement: snapshot.placement,
                style: snapshot.style,
                icon: snapshot.icon,
                text: snapshot.text,
                colorHex: snapshot.colorHex
            )
        }

        return makeInlineNodes(
            placement: snapshot.placement,
            style: snapshot.style,
            text: snapshot.text,
            icon: snapshot.icon,
            colorHex: snapshot.colorHex,
            showInlineLabel: shouldShowInlineLabel(
                mode: config.displayMode,
                text: snapshot.text
            )
        )
    }

    private func unavailableSnapshot(
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        config: Config.BatteryBuiltinConfig
    ) -> (
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        icon: String,
        text: String,
        colorHex: String?
    ) {
        (
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

        switch mode {
        case .none:
            return false
        case .tooltip:
            return false
        case .expand:
            return true
        }
    }

    /// Hover only changes the rendered node tree for inline expand mode.
    private func publishIfHoverAffectsLayout() {
        guard Config.shared.builtinBattery.displayMode == .expand else { return }
        publish()
    }

    /// Keeps the row width stable while toggling the label visually on hover.
    private func inlineLabelNode(
        placement: Config.BuiltinWidgetPlacement,
        text: String,
        colorHex: String?,
        showInlineLabel: Bool
    ) -> WidgetNodeState {
        WidgetNodeState(
            id: "\(rootID)_label",
            root: rootID,
            kind: .item,
            parent: rootID,
            position: placement.position,
            order: 1,
            icon: "",
            text: showInlineLabel ? text : "",
            color: colorHex,
            iconColor: nil,
            labelColor: nil,
            visible: showInlineLabel && !text.isEmpty,
            role: nil,
            receivesMouseHover: nil,
            receivesMouseClick: nil,
            receivesMouseScroll: nil,
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
            paddingX: 0,
            paddingY: 0,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: 4,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1,
            width: nil,
            height: nil,
            yOffset: nil
        )
    }

    /// Resolves the popup text color.
    private func resolvedPopupTextColor(
        popupTextColorHex: String?,
        fallbackColorHex: String?,
        styleTextColorHex: String?
    ) -> String? {
        popupTextColorHex ?? fallbackColorHex ?? styleTextColorHex
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
