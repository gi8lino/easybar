import Foundation

/// Native front-app widget backed by `AeroSpaceService` state.
final class FrontAppNativeWidget: NativeWidget {

    let rootID = "builtin_front_app"

    private let aeroSpaceObserver = NativeAeroSpaceObserver()

    /// Starts the widget and registers AeroSpace interest.
    func start() {
        AeroSpaceService.shared.registerConsumer(rootID)

        // Publish only after fresh AeroSpace data has been resolved.
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

    /// Publishes the currently focused app from `AeroSpaceService`.
    private func publish() {
        let config = Config.shared.builtinFrontApp
        let focused = currentFocusedApp()
        let style = config.style

        var nodes: [WidgetNodeState] = [
            WidgetNodeState(
                id: rootID,
                root: rootID,
                kind: .row,
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
                fontSize: nil,
                iconFontSize: nil,
                labelFontSize: nil,
                value: nil,
                min: nil,
                max: nil,
                step: nil,
                values: nil,
                lineWidth: nil,
                paddingX: style.paddingX,
                paddingY: style.paddingY,
                paddingLeft: nil,
                paddingRight: nil,
                paddingTop: nil,
                paddingBottom: nil,
                spacing: style.spacing,
                backgroundColor: style.backgroundColorHex,
                borderColor: style.borderColorHex,
                borderWidth: style.borderWidth,
                cornerRadius: style.cornerRadius,
                opacity: style.opacity,
                width: nil,
                height: nil,
                yOffset: nil
            )
        ]

        if config.showIcon {
            nodes.append(
                WidgetNodeState(
                    id: "\(rootID)_icon",
                    root: rootID,
                    kind: .item,
                    parent: rootID,
                    position: style.position,
                    order: 0,
                    icon: focused.bundlePath == nil ? style.icon : "",
                    text: "",
                    color: style.textColorHex,
                    iconColor: nil,
                    labelColor: nil,
                    visible: true,
                    role: nil,
                    imagePath: focused.bundlePath,
                    imageSize: config.iconSize,
                    imageCornerRadius: config.iconCornerRadius,
                    fontSize: nil,
                    iconFontSize: nil,
                    labelFontSize: nil,
                    value: nil,
                    min: nil,
                    max: nil,
                    step: nil,
                    values: nil,
                    lineWidth: nil,
                    paddingX: 0,
                    paddingY: 0,
                    paddingLeft: nil,
                    paddingRight: nil,
                    paddingTop: nil,
                    paddingBottom: nil,
                    spacing: 4,
                    backgroundColor: nil,
                    borderColor: nil,
                    borderWidth: nil,
                    cornerRadius: nil,
                    opacity: 1,
                    width: nil,
                    height: nil,
                    yOffset: nil
                )
            )
        }

        if config.showName {
            nodes.append(
                WidgetNodeState(
                    id: "\(rootID)_label",
                    root: rootID,
                    kind: .item,
                    parent: rootID,
                    position: style.position,
                    order: 1,
                    icon: "",
                    text: focused.name.isEmpty ? config.fallbackText : focused.name,
                    color: style.textColorHex,
                    iconColor: nil,
                    labelColor: nil,
                    visible: true,
                    role: nil,
                    imagePath: nil,
                    imageSize: nil,
                    imageCornerRadius: nil,
                    fontSize: nil,
                    iconFontSize: nil,
                    labelFontSize: nil,
                    value: nil,
                    min: nil,
                    max: nil,
                    step: nil,
                    values: nil,
                    lineWidth: nil,
                    paddingX: 0,
                    paddingY: 0,
                    paddingLeft: nil,
                    paddingRight: nil,
                    paddingTop: nil,
                    paddingBottom: nil,
                    spacing: 4,
                    backgroundColor: nil,
                    borderColor: nil,
                    borderWidth: nil,
                    cornerRadius: nil,
                    opacity: 1,
                    width: nil,
                    height: nil,
                    yOffset: nil
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
