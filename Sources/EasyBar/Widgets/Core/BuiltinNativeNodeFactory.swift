import Foundation

enum BuiltinNativeNodeFactory {

    /// Builds one simple root item node.
    static func makeItemNode(
        rootID: String,
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        text: String
    ) -> WidgetNodeState {
        makeRootNode(
            id: rootID,
            kind: .item,
            placement: placement,
            style: style,
            icon: style.icon,
            text: text,
            color: style.textColorHex
        )
    }

    /// Builds one simple root slider node.
    static func makeSliderNode(
        rootID: String,
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        text: String,
        value: Double,
        min: Double,
        max: Double,
        step: Double
    ) -> WidgetNodeState {
        makeRootNode(
            id: rootID,
            kind: .slider,
            placement: placement,
            style: style,
            icon: style.icon,
            text: text,
            color: style.textColorHex,
            value: value,
            min: min,
            max: max,
            step: step
        )
    }

    /// Builds one root row container node.
    static func makeRowContainerNode(
        rootID: String,
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle
    ) -> WidgetNodeState {
        makeRootNode(
            id: rootID,
            kind: .row,
            placement: placement,
            style: style
        )
    }

    /// Builds one root column container node.
    static func makeColumnContainerNode(
        rootID: String,
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle
    ) -> WidgetNodeState {
        makeRootNode(
            id: rootID,
            kind: .column,
            placement: placement,
            style: style
        )
    }

    /// Builds one child item node.
    static func makeChildItemNode(
        rootID: String,
        parentID: String,
        childID: String,
        position: WidgetPosition,
        order: Int,
        icon: String = "",
        text: String = "",
        color: String? = nil,
        visible: Bool = true,
        imagePath: String? = nil,
        imageSize: Double? = nil,
        imageCornerRadius: Double? = nil,
        fontSize: Double? = nil,
        iconFontSize: Double? = nil,
        labelFontSize: Double? = nil,
        spacing: Double? = 4
    ) -> WidgetNodeState {
        makeChildNode(
            id: childID,
            root: rootID,
            kind: .item,
            parent: parentID,
            position: position,
            order: order,
            icon: icon,
            text: text,
            color: color,
            visible: visible,
            imagePath: imagePath,
            imageSize: imageSize,
            imageCornerRadius: imageCornerRadius,
            fontSize: fontSize,
            iconFontSize: iconFontSize,
            labelFontSize: labelFontSize,
            spacing: spacing
        )
    }

    /// Builds one child slider node.
    static func makeChildSliderNode(
        rootID: String,
        parentID: String,
        childID: String,
        position: WidgetPosition,
        order: Int,
        value: Double,
        min: Double,
        max: Double,
        step: Double,
        color: String? = nil,
        visible: Bool = true
    ) -> WidgetNodeState {
        makeChildNode(
            id: childID,
            root: rootID,
            kind: .slider,
            parent: parentID,
            position: position,
            order: order,
            color: color,
            visible: visible,
            value: value,
            min: min,
            max: max,
            step: step
        )
    }

    /// Builds one root node with the shared built-in style defaults.
    private static func makeRootNode(
        id: String,
        kind: WidgetKind,
        placement: Config.BuiltinWidgetPlacement,
        style: Config.BuiltinWidgetStyle,
        icon: String = "",
        text: String = "",
        color: String? = nil,
        value: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil
    ) -> WidgetNodeState {
        WidgetNodeState(
            id: id,
            root: id,
            kind: kind,
            parent: nil,
            position: placement.position,
            order: placement.order,
            icon: icon,
            text: text,
            color: color,
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
            value: value,
            min: min,
            max: max,
            step: step,
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
    }

    /// Builds one child node with the shared child defaults.
    private static func makeChildNode(
        id: String,
        root: String,
        kind: WidgetKind,
        parent: String,
        position: WidgetPosition,
        order: Int,
        icon: String = "",
        text: String = "",
        color: String? = nil,
        visible: Bool = true,
        imagePath: String? = nil,
        imageSize: Double? = nil,
        imageCornerRadius: Double? = nil,
        fontSize: Double? = nil,
        iconFontSize: Double? = nil,
        labelFontSize: Double? = nil,
        value: Double? = nil,
        min: Double? = nil,
        max: Double? = nil,
        step: Double? = nil,
        spacing: Double? = 4
    ) -> WidgetNodeState {
        WidgetNodeState(
            id: id,
            root: root,
            kind: kind,
            parent: parent,
            position: position,
            order: order,
            icon: icon,
            text: text,
            color: color,
            iconColor: nil,
            labelColor: nil,
            visible: visible,
            role: nil,
            imagePath: imagePath,
            imageSize: imageSize,
            imageCornerRadius: imageCornerRadius,
            fontSize: fontSize,
            iconFontSize: iconFontSize,
            labelFontSize: labelFontSize,
            value: value,
            min: min,
            max: max,
            step: step,
            values: nil,
            lineWidth: nil,
            paddingX: 0,
            paddingY: 0,
            paddingLeft: nil,
            paddingRight: nil,
            paddingTop: nil,
            paddingBottom: nil,
            spacing: spacing,
            backgroundColor: nil,
            borderColor: nil,
            borderWidth: nil,
            cornerRadius: nil,
            opacity: 1,
            width: nil,
            height: nil,
            yOffset: nil
        )
    }
}
