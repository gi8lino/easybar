import Foundation

final class DateNativeWidget: NativeWidget {

    let rootID = "builtin_date"

    private var timer: Timer?

    /// Starts the date widget.
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    /// Stops the date widget.
    func stop() {
        timer?.invalidate()
        timer = nil

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Publishes the current date.
    private func publish() {
        let config = Config.shared.builtinDate
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
