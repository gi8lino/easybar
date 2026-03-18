import Foundation

final class CalendarNativeWidget: NativeWidget {

    let rootID = "builtin_calendar"

    private var timer: Timer?
    private let eventObserver = NativeEventObserver()

    func start() {
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

    func stop() {
        eventObserver.stop()

        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
        NativeCalendarStore.shared.clear()
    }

    private func publish() {
        let config = Config.shared.builtinCalendar
        let now = Date()

        let nodes: [WidgetNodeState]

        switch config.layout {
        case .stack:
            nodes = makeStackNodes(config: config, now: now)

        case .inline:
            nodes = makeInlineNodes(config: config, now: now)

        case .item:
            let formatter = DateFormatter()
            formatter.dateFormat = config.format

            nodes = [
                BuiltinWidgetNodeFactory.makeItemNode(
                    rootID: rootID,
                    style: config.style,
                    text: formatter.string(from: now)
                )
            ]
        }

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
        NativeCalendarStore.shared.refresh()
    }

    private func makeStackNodes(
        config: Config.CalendarBuiltinConfig,
        now: Date
    ) -> [WidgetNodeState] {
        [
            WidgetNodeState(
                id: rootID,
                root: rootID,
                kind: .row,
                parent: nil,
                position: config.style.position,
                order: config.style.order,
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
                paddingX: config.style.paddingX,
                paddingY: config.style.paddingY,
                spacing: config.style.spacing,
                backgroundColor: config.style.backgroundColorHex,
                borderColor: config.style.borderColorHex,
                borderWidth: config.style.borderWidth,
                cornerRadius: config.style.cornerRadius,
                opacity: config.style.opacity
            ),

            WidgetNodeState(
                id: "\(rootID)_icon",
                root: rootID,
                kind: .item,
                parent: rootID,
                position: config.style.position,
                order: 0,
                icon: config.style.icon,
                text: "",
                color: config.style.textColorHex,
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
                id: "\(rootID)_text_column",
                root: rootID,
                kind: .column,
                parent: rootID,
                position: config.style.position,
                order: 1,
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
                paddingX: 0,
                paddingY: 0,
                spacing: config.lineSpacing,
                backgroundColor: nil,
                borderColor: nil,
                borderWidth: nil,
                cornerRadius: nil,
                opacity: 1
            ),

            makeTextNode(
                id: "\(rootID)_top",
                parent: "\(rootID)_text_column",
                position: config.style.position,
                order: 0,
                text: formatDate(now, format: config.topFormat),
                color: config.topTextColorHex ?? config.style.textColorHex
            ),

            makeTextNode(
                id: "\(rootID)_bottom",
                parent: "\(rootID)_text_column",
                position: config.style.position,
                order: 1,
                text: formatDate(now, format: config.bottomFormat),
                color: config.bottomTextColorHex ?? config.style.textColorHex
            )
        ]
    }

    private func makeInlineNodes(
        config: Config.CalendarBuiltinConfig,
        now: Date
    ) -> [WidgetNodeState] {
        [
            WidgetNodeState(
                id: rootID,
                root: rootID,
                kind: .row,
                parent: nil,
                position: config.style.position,
                order: config.style.order,
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
                paddingX: config.style.paddingX,
                paddingY: config.style.paddingY,
                spacing: config.style.spacing,
                backgroundColor: config.style.backgroundColorHex,
                borderColor: config.style.borderColorHex,
                borderWidth: config.style.borderWidth,
                cornerRadius: config.style.cornerRadius,
                opacity: config.style.opacity
            ),

            WidgetNodeState(
                id: "\(rootID)_icon",
                root: rootID,
                kind: .item,
                parent: rootID,
                position: config.style.position,
                order: 0,
                icon: config.style.icon,
                text: "",
                color: config.style.textColorHex,
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

            makeTextNode(
                id: "\(rootID)_left",
                parent: rootID,
                position: config.style.position,
                order: 1,
                text: formatDate(now, format: config.topFormat),
                color: config.topTextColorHex ?? config.style.textColorHex
            ),

            makeTextNode(
                id: "\(rootID)_right",
                parent: rootID,
                position: config.style.position,
                order: 2,
                text: formatDate(now, format: config.bottomFormat),
                color: config.bottomTextColorHex ?? config.style.textColorHex
            )
        ]
    }

    private func makeTextNode(
        id: String,
        parent: String,
        position: WidgetPosition,
        order: Int,
        text: String,
        color: String?
    ) -> WidgetNodeState {
        WidgetNodeState(
            id: id,
            root: rootID,
            kind: .item,
            parent: parent,
            position: position,
            order: order,
            icon: "",
            text: text,
            color: color,
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
        )
    }

    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
