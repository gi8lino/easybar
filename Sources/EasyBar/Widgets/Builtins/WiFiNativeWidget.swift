import Foundation
import EasyBarShared

final class WiFiNativeWidget: NativeWidget {
    let rootID = "builtin_wifi"

    private let eventObserver = EasyBarEventObserver()
    private var storeToken: NSObjectProtocol?
    private var isHovered = false

    func start() {
        let config = Config.shared.builtinWiFi
        Logger.info("starting native widget id=\(rootID) enabled=\(config.enabled) position=\(config.position.rawValue)")

        eventObserver.start { [weak self] payload in
            guard let self else { return }
            guard payload.widgetID == self.rootID else { return }
            guard let event = payload.widgetEvent else { return }

            switch event {
            case .mouseEntered:
                guard !self.isHovered else { return }
                self.isHovered = true
                self.publish()

            case .mouseExited:
                guard self.isHovered else { return }
                self.isHovered = false
                self.publish()

            default:
                break
            }
        }

        storeToken = NotificationCenter.default.addObserver(
            forName: NativeWiFiStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.publish()
        }

        if Config.shared.networkAgentEnabled {
            NetworkAgentClient.shared.start()
        } else {
            Logger.info("network agent disabled in config")
        }

        publish()
    }

    func stop() {
        Logger.info("stopping native widget id=\(rootID)")

        eventObserver.stop()
        if let storeToken {
            NotificationCenter.default.removeObserver(storeToken)
            self.storeToken = nil
        }
        isHovered = false

        if Config.shared.networkAgentEnabled {
            NetworkAgentClient.shared.stop()
        }

        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let config = Config.shared.builtinWiFi
        let snapshot = NativeWiFiStore.shared.snapshot
        let placement = config.placement
        let style = config.style

        var nodes: [WidgetNodeState] = [
            BuiltinNativeNodeFactory.makeRowContainerNode(
                rootID: rootID,
                placement: placement,
                style: style
            )
        ]

        nodes.append(
            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_icon",
                position: placement.position,
                order: 13,
                icon: resolvedSignalIcon(snapshot: snapshot),
                color: resolvedSignalColor(snapshot: snapshot, config: config),
                fontSize: 16
            )
        )

        let labelText = resolvedLabelText(snapshot: snapshot, config: config)
        nodes.append(
            BuiltinNativeNodeFactory.makeChildItemNode(
                rootID: rootID,
                parentID: rootID,
                childID: "\(rootID)_label",
                position: placement.position,
                order: 13,
                text: labelText,
                color: config.textColorHex,
                visible: config.showSSIDOnHover && isHovered && !labelText.isEmpty,
                spacing: 4
            )
        )

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
    }

    private func resolvedSignalBars(snapshot: NetworkAgentSnapshot?) -> Int {
        guard let snapshot, snapshot.accessGranted else { return 0 }
        return max(0, min(4, snapshot.signalBars))
    }

    private func resolvedSignalIcon(snapshot: NetworkAgentSnapshot?) -> String {
        let bars = resolvedSignalBars(snapshot: snapshot)

        switch bars {
        case 4:
            return "󰤨"
        case 3:
            return "󰤥"
        case 2:
            return "󰤢"
        case 1:
            return "󰤟"
        default:
            return "󰤮"
        }
    }

    private func resolvedSignalColor(
        snapshot: NetworkAgentSnapshot?,
        config: Config.WiFiBuiltinConfig
    ) -> String {
        guard let snapshot, snapshot.accessGranted, snapshot.ssid != nil else {
            return config.inactiveColorHex
        }

        return config.activeColorHex
    }

    private func resolvedLabelText(
        snapshot: NetworkAgentSnapshot?,
        config: Config.WiFiBuiltinConfig
    ) -> String {
        guard let snapshot else { return config.disconnectedText }

        guard snapshot.accessGranted else {
            return config.deniedText
        }

        return snapshot.ssid ?? config.disconnectedText
    }
}
