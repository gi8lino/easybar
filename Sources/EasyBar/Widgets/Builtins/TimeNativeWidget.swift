import Foundation

final class TimeNativeWidget: NativeWidget {

    let rootID = "builtin_time"

    private var timer: Timer?

    /// Starts the time widget.
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    /// Stops the time widget.
    func stop() {
        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Publishes the current time.
    private func publish() {
        let config = Config.shared.builtinTime
        let formatter = DateFormatter()
        formatter.dateFormat = config.format

        let node = BuiltinNativeNodeFactory.makeItemNode(
            rootID: rootID,
            placement: config.placement,
            style: config.style,
            text: formatter.string(from: Date())
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }
}
