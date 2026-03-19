import Foundation
import TOMLKit

extension Config {

    /// Battery color mode.
    enum BuiltinBatteryColorMode: String {
        case dynamic
        case fixed
    }

    /// Battery hover text mode.
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
                enabled: false,
                position: .right,
                order: 10
            ),
            style: .init(
                icon: "🔋",
                textColorHex: nil,
                backgroundColorHex: nil,
                borderColorHex: nil,
                borderWidth: 0,
                cornerRadius: 0,
                paddingX: 8,
                paddingY: 4,
                spacing: 8,
                opacity: 1
            ),
            content: .init(
                showPercentage: true,
                unavailableText: "n/a",
                iconSize: 16,
                colorMode: .dynamic,
                fixedColorHex: nil,
                displayMode: .expand,
                colors: .init(
                    highColorHex: "#8bd5ca",
                    mediumColorHex: "#eed49f",
                    lowColorHex: "#f5a97f",
                    criticalColorHex: "#ed8796"
                )
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

        builtinBattery = BatteryBuiltinConfig(
            placement: placement,
            style: style,
            content: content
        )
    }
}
