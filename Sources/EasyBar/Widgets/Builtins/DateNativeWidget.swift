import Foundation

final class DateNativeWidget: NativeWidget {

    let rootID = "builtin_date"

    private var timer: Timer?

    /// Starts the date widget.
    func start() {
        startTimer()
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

        let node = BuiltinNativeNodeFactory.makeItemNode(
            rootID: rootID,
            placement: config.placement,
            style: config.style,
            text: makeFormatter(format: config.format).string(from: Date())
        )

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }

    /// Starts the timer that drives date updates.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.publish()
        }
    }

    /// Builds one formatter for the configured date format.
    private func makeFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter
    }
}
