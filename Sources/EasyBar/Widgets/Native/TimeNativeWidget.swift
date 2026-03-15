import Foundation

final class TimeNativeWidget: NativeWidget {

    let rootID = "builtin_time"

    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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
        let config = Config.shared.builtinTime
        let formatter = DateFormatter()
        formatter.dateFormat = config.format

        let node = BuiltinWidgetNodeFactory.makeItemNode(
            rootID: rootID,
            style: config.style,
            text: formatter.string(from: Date())
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }
}
