import Foundation

final class SpacesNativeWidget: NativeWidget {

    let rootID = "builtin_spaces"

    func start() {
        publish()
    }

    func stop() {
        WidgetStore.shared.apply(root: rootID, nodes: [])
    }

    private func publish() {
        let style = Config.shared.builtinSpaces.style

        let node = WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: "spaces",
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

        WidgetStore.shared.apply(root: rootID, nodes: [node])
    }
}
