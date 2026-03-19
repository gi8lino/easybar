import Foundation

final class CalendarNativeWidget: NativeWidget {

    let rootID = "builtin_calendar"

    private var timer: Timer?
    private let eventObserver = EasyBarEventObserver()

    /// Starts the calendar widget.
    func start() {
        let config = Config.shared.builtinCalendar

        Logger.info("starting native widget id=\(rootID) enabled=\(config.enabled) layout=\(config.layout.rawValue) position=\(config.position.rawValue) days=\(config.days) show_birthdays=\(config.showBirthdays)")

        CalendarEvents.shared.subscribeCalendar()

        eventObserver.start { [weak self] payload in
            guard let self, let event = payload.appEvent else {
                return
            }

            if event == .calendarChange || event == .minuteTick {
                self.publish()
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    /// Stops the calendar widget.
    func stop() {
        Logger.info("stopping native widget id=\(rootID)")

        eventObserver.stop()

        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
        NativeCalendarStore.shared.clear()
    }

    /// Publishes the current calendar nodes.
    private func publish() {
        let config = Config.shared.builtinCalendar
        let now = Date()

        Logger.debug("publishing native calendar widget layout=\(config.layout.rawValue)")

        let nodes: [WidgetNodeState]

        switch config.layout {
        case .stack:
            nodes = makeStackNodes(config: config, now: now)

        case .inline:
            nodes = makeInlineNodes(config: config, now: now)

        case .item:
            let formatter = DateFormatter()
            formatter.dateFormat = config.itemFormat

            nodes = [
                BuiltinNativeNodeFactory.makeItemNode(
                    rootID: rootID,
                    placement: config.placement,
                    style: config.style,
                    text: formatter.string(from: now)
                )
            ]
        }

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
        NativeCalendarStore.shared.refresh()
    }

    /// Builds stack-layout nodes.
    private func makeStackNodes(
        config: Config.CalendarBuiltinConfig,
        now: Date
    ) -> [WidgetNodeState] {
        let placement = config.placement
        let style = config.style

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
                icon: style.icon,
                color: style.textColorHex
            ),

            WidgetNodeState(
                id: "\(rootID)_text_column",
                root: rootID,
                kind: .column,
                parent: rootID,
                position: placement.position,
                order: 1,
                icon: "",
                text: "",
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
                paddingX: 0,
                paddingY: 0,
                paddingLeft: nil,
                paddingRight: nil,
                paddingTop: nil,
                paddingBottom: nil,
                spacing: config.lineSpacing,
                backgroundColor: nil,
                borderColor: nil,
                borderWidth: nil,
                cornerRadius: nil,
                opacity: 1,
                width: nil,
                height: nil,
                yOffset: nil
            ),

            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: "\(rootID)_text_column",
                childID: "\(rootID)_top",
                position: placement.position,
                order: 0,
                text: formatDate(now, format: config.topFormat),
                color: config.topTextColorHex ?? style.textColorHex
            ),

            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: "\(rootID)_text_column",
                childID: "\(rootID)_bottom",
                position: placement.position,
                order: 1,
                text: formatDate(now, format: config.bottomFormat),
                color: config.bottomTextColorHex ?? style.textColorHex
            )
        ]
    }

    /// Builds inline-layout nodes.
    private func makeInlineNodes(
        config: Config.CalendarBuiltinConfig,
        now: Date
    ) -> [WidgetNodeState] {
        let placement = config.placement
        let style = config.style

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
                icon: style.icon,
                color: style.textColorHex
            ),

            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_left",
                position: placement.position,
                order: 1,
                text: formatDate(now, format: config.topFormat),
                color: config.topTextColorHex ?? style.textColorHex
            ),

            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_right",
                position: placement.position,
                order: 2,
                text: formatDate(now, format: config.bottomFormat),
                color: config.bottomTextColorHex ?? style.textColorHex
            )
        ]
    }

    /// Formats one date string.
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
