import Foundation

/// Native front-app widget backed by `AeroSpaceService` state.
final class FrontAppNativeWidget: NativeWidget {

    let rootID = "builtin_front_app"

    private let aeroSpaceObserver = AeroSpaceUpdateObserver()

    /// Starts the widget and registers AeroSpace interest.
    func start() {
        AeroSpaceService.shared.registerConsumer(rootID)

        aeroSpaceObserver.start { [weak self] in
            self?.publish()
        }

        publish()
    }

    /// Stops the widget and removes observers.
    func stop() {
        aeroSpaceObserver.stop()
        AeroSpaceService.shared.unregisterConsumer(rootID)
        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Publishes the currently focused app.
    private func publish() {
        let config = Config.shared.builtinFrontApp
        let placement = config.placement
        let style = config.style
        let focused = currentFocusedApp()

        var nodes: [WidgetNodeState] = [
            BuiltinNativeNodeFactory.makeRowContainerNode(
                rootID: rootID,
                placement: placement,
                style: style
            )
        ]

        if config.showIcon {
            nodes.append(
                BuiltinNativeNodeFactory.makeChildItemNode(
                    rootID: rootID,
                    parentID: rootID,
                    childID: "\(rootID)_icon",
                    position: placement.position,
                    order: 0,
                    icon: focused.bundlePath == nil ? style.icon : "",
                    text: "",
                    color: style.textColorHex,
                    imagePath: focused.bundlePath,
                    imageSize: config.iconSize,
                    imageCornerRadius: config.iconCornerRadius
                )
            )
        }

        if config.showName {
            nodes.append(
                BuiltinNativeNodeFactory.makeChildItemNode(
                    rootID: rootID,
                    parentID: rootID,
                    childID: "\(rootID)_label",
                    position: placement.position,
                    order: 1,
                    text: focused.name.isEmpty ? config.fallbackText : focused.name,
                    color: style.textColorHex
                )
            )
        }

        WidgetStore.shared.apply(root: rootID, nodes: nodes)
    }

    /// Returns the focused app already resolved by `AeroSpaceService`.
    private func currentFocusedApp() -> (name: String, bundlePath: String?) {
        guard let app = AeroSpaceService.shared.focusedApp else {
            return ("", nil)
        }

        return (app.name, app.bundlePath)
    }
}
