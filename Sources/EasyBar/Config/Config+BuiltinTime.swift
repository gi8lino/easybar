import Foundation
import TOMLKit

extension Config {

    /// Built-in time widget config.
    struct TimeBuiltinConfig {
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

        static let `default` = TimeBuiltinConfig(
            placement: .init(
                enabled: false,
                position: .right,
                order: 40
            ),
            style: .init(
                icon: "🕒",
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
                format: "HH:mm"
            )
        )
    }

    /// Parses the built-in time widget.
    func parseTimeBuiltin(from builtins: TOMLTable) throws {
        guard let time = builtins["time"]?.table else { return }

        let placement = try parseBuiltinPlacement(
            from: time,
            path: "builtins.time",
            fallback: builtinTime.placement
        )

        let styleTable = time["style"]?.table ?? TOMLTable()
        let contentTable = time["content"]?.table ?? TOMLTable()

        let style = try parseBuiltinStyle(
            from: styleTable,
            path: "builtins.time.style",
            fallback: builtinTime.style
        )

        let format = try optionalString(
            contentTable["format"],
            path: "builtins.time.content.format"
        ) ?? builtinTime.format

        builtinTime = TimeBuiltinConfig(
            placement: placement,
            style: style,
            content: .init(format: format)
        )
    }
}
