import Foundation

/// Native wrapper node for the SwiftUI spaces widget.
final class SpacesNativeWidget: NativeWidget {

    let rootID = "builtin_spaces"

    private var aeroSpaceObserver: NSObjectProtocol?

    /// Starts the widget and listens for AeroSpace state updates.
    func start() {
        AeroSpaceService.shared.registerConsumer(rootID)

        aeroSpaceObserver = NotificationCenter.default.addObserver(
            forName: .easyBarAeroSpaceDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.publish()
        }

        publish()
    }

    /// Stops the widget and unregisters AeroSpace interest.
    func stop() {
        if let aeroSpaceObserver {
            NotificationCenter.default.removeObserver(aeroSpaceObserver)
            self.aeroSpaceObserver = nil
        }

        AeroSpaceService.shared.unregisterConsumer(rootID)
        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    /// Publishes the container node consumed by `SpacesWidgetView`.
    private func publish() {
        let style = Config.shared.builtinSpaces.style

        let node = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: .spaces,
            parent: nil,
            position: style.position,
            order: style.order,
            icon: "",
            text: "",
            color: style.textColorHex,
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

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }
}
