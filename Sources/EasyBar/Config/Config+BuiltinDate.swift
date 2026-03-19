import Foundation
import TOMLKit

extension Config {

    /// Built-in date widget config.
    struct DateBuiltinConfig {
        struct Content {
            var format: String
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

        var format: String {
            get { content.format }
            set { content.format = newValue }
        }

        static let `default` = DateBuiltinConfig(
            placement: .init(
                enabled: false,
                position: .right,
                order: 50
            ),
            style: .init(
                icon: "📅",
                textColorHex: "#ffffff",
                backgroundColorHex: "#1a1a1a",
                borderColorHex: "#333333",
                borderWidth: 1,
                cornerRadius: 8,
                paddingX: 8,
                paddingY: 4,
                spacing: 6,
                opacity: 1
            ),
            content: .init(
                format: "yyyy-MM-dd"
            )
        )
    }

    /// Parses the built-in date widget.
    func parseDateBuiltin(from builtins: TOMLTable) throws {
        guard let date = builtins["date"]?.table else { return }

        let placement = try parseBuiltinPlacement(
            from: date,
            path: "builtins.date",
            fallback: builtinDate.placement
        )

        let styleTable = date["style"]?.table ?? TOMLTable()
        let contentTable = date["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.date.style",
            fallback: builtinDate.style
        )

        let format = try optionalString(
            contentTable["format"],
            path: "builtins.date.content.format"
        ) ?? builtinDate.format

        builtinDate = DateBuiltinConfig(
            placement: placement,
            style: style,
            content: .init(format: format)
        )
    }
}
