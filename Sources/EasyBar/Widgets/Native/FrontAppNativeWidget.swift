import Foundation

final class FrontAppNativeWidget: NativeWidget {

    let rootID = "builtin_front_app"

    private var eventObserver: NSObjectProtocol?

    func start() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: .easyBarEvent,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let payload = notification.object as? [String: String],
                let event = payload["event"]
            else {
                return
            }

            switch event {
            case "app_switch", "focus_change", "workspace_change", "system_woke":
                self?.publish()
            default:
                break
            }
        }

        publish()
    }

    func stop() {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
            self.eventObserver = nil
        }

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let config = Config.shared.builtinFrontApp
        let focused = readFocusedApp()
        let style = config.style

        var nodes: [WidgetNodeState] = [
            WidgetNodeState(
                id: rootID,
                root: rootID,
                kind: "row",
                parent: nil,
                position: style.position,
                order: style.order,
                icon: "",
                text: "",
                color: nil,
                visible: true,
                role: nil,
                imagePath: nil,
                imageSize: nil,
                imageCornerRadius: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: style.paddingX,
                paddingY: style.paddingY,
                spacing: style.spacing,
                backgroundColor: style.backgroundColorHex,
                borderColor: style.borderColorHex,
                borderWidth: style.borderWidth,
                cornerRadius: style.cornerRadius,
                opacity: style.opacity
            )
        ]

        if config.showIcon {
            nodes.append(
                WidgetNodeState(
                    id: "\(rootID)_icon",
                    root: rootID,
                    kind: "item",
                    parent: rootID,
                    position: style.position,
                    order: 0,
                    icon: focused.bundlePath == nil ? style.icon : "",
                    text: "",
                    color: style.textColorHex,
                    visible: true,
                    role: nil,
                    imagePath: focused.bundlePath,
                    imageSize: config.iconSize,
                    imageCornerRadius: config.iconCornerRadius,
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
            )
        }

        if config.showName {
            nodes.append(
                WidgetNodeState(
                    id: "\(rootID)_label",
                    root: rootID,
                    kind: "item",
                    parent: rootID,
                    position: style.position,
                    order: 1,
                    icon: "",
                    text: focused.name.isEmpty ? config.fallbackText : focused.name,
                    color: style.textColorHex,
                    visible: true,
                    role: nil,
                    imagePath: nil,
                    imageSize: nil,
                    imageCornerRadius: nil,
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
            )
        }

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
    }

    private func readFocusedApp() -> (name: String, bundlePath: String?) {
        guard let output = runAeroSpace(arguments: [
            "list-windows",
            "--focused",
            "--format",
            "%{app-bundle-path} | %{app-name}"
        ]) else {
            return ("", nil)
        }

        let parts = output
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let bundlePath = parts.first.flatMap { $0.isEmpty ? nil : $0 }
        let name = parts.count > 1 ? parts[1] : ""

        return (name, bundlePath)
    }

    private func runAeroSpace(arguments: [String]) -> String? {
        guard let executable = resolveAeroSpacePath() else {
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            Logger.debug("front app widget failed to run aerospace: \(error)")
            return nil
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolveAeroSpacePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/aerospace",
            "/usr/local/bin/aerospace",
            "/Applications/AeroSpace.app/Contents/MacOS/aerospace"
        ]

        let fm = FileManager.default
        return candidates.first(where: { fm.isExecutableFile(atPath: $0) })
    }
}
