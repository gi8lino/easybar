import Foundation

final class TimeNativeWidget: NativeWidget {

    let rootID = "builtin_time"

    private var timer: Timer?

    /// Starts the time widget.
    func start() {
        startTimer()
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

        let node = BuiltinNativeNodeFactory.makeItemNode(
            rootID: rootID,
            placement: config.placement,
            style: config.style,
            text: makeFormatter(format: config.format).string(from: Date())
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }

    /// Starts the timer that drives time updates.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.publish()
        }
    }

    /// Builds one formatter for the configured time format.
    private func makeFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter
    }
}
