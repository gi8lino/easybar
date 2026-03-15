import Foundation

final class DateNativeWidget: NativeWidget {

    let rootID = "builtin_date"

    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let formatter = DateFormatter()
        formatter.dateFormat = Config.shared.builtinDateFormat

        let node = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: "item",
            parent: nil,
            position: Config.shared.builtinDatePosition,
            order: Config.shared.builtinDateOrder,
            icon: "📅",
            text: formatter.string(from: Date()),
            color: nil,
            visible: true,
            role: nil,
            value: nil,
            min: nil,
            max: nil,
            step: nil,
            values: nil,
            lineWidth: nil,
            paddingX: 8,
            paddingY: 4,
            spacing: 6,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }
}
