import Foundation
import TOMLKit

extension Config {

    /// Battery color mode.
    enum BuiltinBatteryColorMode: String {
        case dynamic
        case fixed
    }

    /// Battery percentage display mode.
    enum BuiltinBatteryDisplayMode: String {
        case none
        case tooltip
        case expand
    }

    /// Battery severity colors.
    struct BuiltinBatteryColors {
        var highColorHex: String
        var mediumColorHex: String
        var lowColorHex: String
        var criticalColorHex: String
    }

    /// Battery hover popup style used for `display_mode = "tooltip"`.
    struct BuiltinBatteryPopup {
        var textColorHex: String?
        var backgroundColorHex: String
        var borderColorHex: String
        var borderWidth: Double
        var cornerRadius: Double
        var paddingX: Double
        var paddingY: Double
        var marginX: Double
        var marginY: Double
    }

    /// Built-in battery widget config.
    struct BatteryBuiltinConfig {

        struct Content {
            var showPercentage: Bool
            var unavailableText: String
            var iconSize: Double
            var colorMode: BuiltinBatteryColorMode
            var fixedColorHex: String?
            var displayMode: BuiltinBatteryDisplayMode
            var colors: BuiltinBatteryColors
        }

        var placement: BuiltinWidgetPlacement
        var style: BuiltinWidgetStyle
        var content: Content
        var popup: BuiltinBatteryPopup

        var enabled: Bool {
            get { placement.enabled }
            set { placement.enabled = newValue }
        }

        var position: WidgetPosition {
            get { placement.position }
            set { placement.position = newValue }
        }

        var order: Int {
            get { placement.order }
            set { placement.order = newValue }
        }

        var showPercentage: Bool {
            get { content.showPercentage }
            set { content.showPercentage = newValue }
        }

        var unavailableText: String {
            get { content.unavailableText }
            set { content.unavailableText = newValue }
        }

        var iconSize: Double {
            get { content.iconSize }
            set { content.iconSize = newValue }
        }

        var colorMode: BuiltinBatteryColorMode {
            get { content.colorMode }
            set { content.colorMode = newValue }
        }

        var fixedColorHex: String? {
            get { content.fixedColorHex }
            set { content.fixedColorHex = newValue }
        }

        var displayMode: BuiltinBatteryDisplayMode {
            get { content.displayMode }
            set { content.displayMode = newValue }
        }

        var colors: BuiltinBatteryColors {
            get { content.colors }
            set { content.colors = newValue }
        }

        static let `default` = BatteryBuiltinConfig(
            placement: .init(
                enabled: true,
                position: .right,
                order: 20
            ),
            style: .init(
                icon: "🔋",
                textColorHex: "#ffffff",
                backgroundColorHex: "#1a1a1a",
                borderColorHex: "#333333",
                borderWidth: 1,
                cornerRadius: 8,
                paddingX: 8,
                paddingY: 4,
                spacing: 10,
                opacity: 1
            ),
            content: .init(
                showPercentage: true,
                unavailableText: "n/a",
                iconSize: 18,
                colorMode: .dynamic,
                fixedColorHex: "#8aadf4",
                displayMode: .expand,
                colors: .init(
                    highColorHex: "#8bd5ca",
                    mediumColorHex: "#eed49f",
                    lowColorHex: "#f5a97f",
                    criticalColorHex: "#ed8796"
                )
            ),
            popup: .init(
                textColorHex: "#ffffff",
                backgroundColorHex: "#111111",
                borderColorHex: "#444444",
                borderWidth: 1,
                cornerRadius: 8,
                paddingX: 8,
                paddingY: 6,
                marginX: 0,
                marginY: 8
            )
        )
    }

    /// Parses the built-in battery widget.
    func parseBatteryBuiltin(from builtins: TOMLTable) throws {
        guard let battery = builtins["battery"]?.table else { return }

        let placement = try parseBuiltinPlacement(
            from: battery,
            path: "builtins.battery",
            fallback: builtinBattery.placement
        )

        let styleTable = battery["style"]?.table ?? TOMLTable()
        let contentTable = battery["content"]?.table ?? TOMLTable()
        let colorsTable = battery["colors"]?.table ?? TOMLTable()
        let popupTable = battery["popup"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.battery.style",
            fallback: builtinBattery.style
        )

        let content = BatteryBuiltinConfig.Content(
            showPercentage: try optionalBool(
                contentTable["show_percentage"],
                path: "builtins.battery.content.show_percentage"
            ) ?? builtinBattery.showPercentage,
            unavailableText: try optionalString(
                contentTable["unavailable_text"],
                path: "builtins.battery.content.unavailable_text"
            ) ?? builtinBattery.unavailableText,
            iconSize: try optionalNumber(
                contentTable["icon_size"],
                path: "builtins.battery.content.icon_size"
            ) ?? builtinBattery.iconSize,
            colorMode: normalizedBatteryColorMode(
                try optionalString(
                    contentTable["color_mode"],
                    path: "builtins.battery.content.color_mode"
                ) ?? builtinBattery.colorMode.rawValue
            ),
            fixedColorHex: try optionalString(
                contentTable["fixed_color"],
                path: "builtins.battery.content.fixed_color"
            ) ?? builtinBattery.fixedColorHex,
            displayMode: normalizedBatteryDisplayMode(
                try optionalString(
                    contentTable["display_mode"],
                    path: "builtins.battery.content.display_mode"
                ) ?? builtinBattery.displayMode.rawValue
            ),
            colors: .init(
                highColorHex: try optionalString(
                    colorsTable["high"],
                    path: "builtins.battery.colors.high"
                ) ?? builtinBattery.colors.highColorHex,
                mediumColorHex: try optionalString(
                    colorsTable["medium"],
                    path: "builtins.battery.colors.medium"
                ) ?? builtinBattery.colors.mediumColorHex,
                lowColorHex: try optionalString(
                    colorsTable["low"],
                    path: "builtins.battery.colors.low"
                ) ?? builtinBattery.colors.lowColorHex,
                criticalColorHex: try optionalString(
                    colorsTable["critical"],
                    path: "builtins.battery.colors.critical"
                ) ?? builtinBattery.colors.criticalColorHex
            )
        )

        let popup = BuiltinBatteryPopup(
            textColorHex: try optionalString(
                popupTable["text_color"],
                path: "builtins.battery.popup.text_color"
            ) ?? builtinBattery.popup.textColorHex,
            backgroundColorHex: try optionalString(
                popupTable["background_color"],
                path: "builtins.battery.popup.background_color"
            ) ?? builtinBattery.popup.backgroundColorHex,
            borderColorHex: try optionalString(
                popupTable["border_color"],
                path: "builtins.battery.popup.border_color"
            ) ?? builtinBattery.popup.borderColorHex,
            borderWidth: try optionalNumber(
                popupTable["border_width"],
                path: "builtins.battery.popup.border_width"
            ) ?? builtinBattery.popup.borderWidth,
            cornerRadius: try optionalNumber(
                popupTable["corner_radius"],
                path: "builtins.battery.popup.corner_radius"
            ) ?? builtinBattery.popup.cornerRadius,
            paddingX: try optionalNumber(
                popupTable["padding_x"],
                path: "builtins.battery.popup.padding_x"
            ) ?? builtinBattery.popup.paddingX,
            paddingY: try optionalNumber(
                popupTable["padding_y"],
                path: "builtins.battery.popup.padding_y"
            ) ?? builtinBattery.popup.paddingY,
            marginX: try optionalNumber(
                popupTable["margin_x"],
                path: "builtins.battery.popup.margin_x"
            ) ?? builtinBattery.popup.marginX,
            marginY: try optionalNumber(
                popupTable["margin_y"],
                path: "builtins.battery.popup.margin_y"
            ) ?? builtinBattery.popup.marginY
        )

        builtinBattery = BatteryBuiltinConfig(
            placement: placement,
            style: style,
            content: content,
            popup: popup
        )
    }
}
