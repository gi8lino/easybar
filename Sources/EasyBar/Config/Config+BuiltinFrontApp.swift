import Foundation
import TOMLKit

extension Config {

    /// Built-in front app widget config.
    struct FrontAppBuiltinConfig {
        struct Content {
            var showIcon: Bool
            var showName: Bool
            var fallbackText: String
            var iconSize: Double
            var iconCornerRadius: Double
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

        var showIcon: Bool {
            get { content.showIcon }
            set { content.showIcon = newValue }
        }

        var showName: Bool {
            get { content.showName }
            set { content.showName = newValue }
        }

        var fallbackText: String {
            get { content.fallbackText }
            set { content.fallbackText = newValue }
        }

        var iconSize: Double {
            get { content.iconSize }
            set { content.iconSize = newValue }
        }

        var iconCornerRadius: Double {
            get { content.iconCornerRadius }
            set { content.iconCornerRadius = newValue }
        }

        static let `default` = FrontAppBuiltinConfig(
            placement: .init(
                enabled: false,
                position: .left,
                order: 15
            ),
            style: .init(
                icon: "􀈔",
                textColorHex: nil,
                backgroundColorHex: nil,
                borderColorHex: nil,
                borderWidth: 0,
                cornerRadius: 0,
                paddingX: 8,
                paddingY: 4,
                spacing: 6,
                opacity: 1
            ),
            content: .init(
                showIcon: true,
                showName: true,
                fallbackText: "No App",
                iconSize: 14,
                iconCornerRadius: 4
            )
        )
    }

    /// Parses the built-in front app widget.
    func parseFrontAppBuiltin(from builtins: TOMLTable) throws {
        guard let frontApp = builtins["front_app"]?.table else { return }

        let placement = try parseBuiltinPlacement(
            from: frontApp,
            path: "builtins.front_app",
            fallback: builtinFrontApp.placement
        )

        let styleTable = frontApp["style"]?.table ?? TOMLTable()
        let contentTable = frontApp["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.front_app.style",
            fallback: builtinFrontApp.style
        )

        let content = FrontAppBuiltinConfig.Content(
            showIcon: try optionalBool(
                contentTable["show_icon"],
                path: "builtins.front_app.content.show_icon"
            ) ?? builtinFrontApp.showIcon,
            showName: try optionalBool(
                contentTable["show_name"],
                path: "builtins.front_app.content.show_name"
            ) ?? builtinFrontApp.showName,
            fallbackText: try optionalString(
                contentTable["fallback_text"],
                path: "builtins.front_app.content.fallback_text"
            ) ?? builtinFrontApp.fallbackText,
            iconSize: try optionalNumber(
                contentTable["icon_size"],
                path: "builtins.front_app.content.icon_size"
            ) ?? builtinFrontApp.iconSize,
            iconCornerRadius: try optionalNumber(
                contentTable["icon_corner_radius"],
                path: "builtins.front_app.content.icon_corner_radius"
            ) ?? builtinFrontApp.iconCornerRadius
        )

        builtinFrontApp = FrontAppBuiltinConfig(
            placement: placement,
            style: style,
            content: content
        )
    }
}
