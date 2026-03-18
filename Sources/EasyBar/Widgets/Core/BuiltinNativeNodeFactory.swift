import Foundation

enum BuiltinNativeNodeFactory {

    static func makeItemNode(
        rootID: String,
        style: Config.BuiltinWidgetStyle,
        text: String
    ) -> WidgetNodeState {
        WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: .item,
            parent: nil,
            position: style.position,
            order: style.order,
            icon: style.icon,
            text: text,
            color: style.textColorHex,
            visible: true,
            role: nil,
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
    }

    static func makeSliderNode(
        rootID: String,
        style: Config.BuiltinWidgetStyle,
        text: String,
        value: Double,
        min: Double,
        max: Double,
        step: Double
    ) -> WidgetNodeState {
        WidgetNodeState(
            id: rootID,
            root: rootID,
            kind: .slider,
            parent: nil,
            position: style.position,
            order: style.order,
            icon: style.icon,
            text: text,
            color: style.textColorHex,
            visible: true,
            role: nil,
            value: value,
            min: min,
            max: max,
            step: step,
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
    }
}
