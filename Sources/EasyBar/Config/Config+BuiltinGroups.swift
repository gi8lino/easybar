import Foundation
import TOMLKit

extension Config {

    /// Native group container config used by built-in widgets.
    struct BuiltinGroupConfig {
        var id: String
        var placement: BuiltinWidgetPlacement
        var style: BuiltinWidgetStyle
    }

    /// Parses the built-in native groups.
    func parseBuiltinGroups(from builtins: TOMLTable) throws {
        guard let groups = builtins["groups"]?.table else { return }

        var parsed: [BuiltinGroupConfig] = []

        for key in groups.keys.sorted() {
            guard let groupTable = groups[key]?.table else { continue }

            let placement = try parseBuiltinPlacement(
                from: groupTable,
                path: "builtins.groups.\(key)",
                fallback: .init(
                    enabled: true,
                    position: .right,
                    order: 0,
                    group: nil
                )
            )

            let styleTable = groupTable["style"]?.table ?? groupTable
            let style = try parseBuiltinStyle(
                from: styleTable,
                path: "builtins.groups.\(key).style",
                fallback: .init(
                    icon: "",
                    textColorHex: nil,
                    backgroundColorHex: "#1a1a1a",
                    borderColorHex: "#333333",
                    borderWidth: 1,
                    cornerRadius: 8,
                    marginX: 0,
                    marginY: 0,
                    paddingX: 8,
                    paddingY: 4,
                    spacing: 6,
                    opacity: 1
                )
            )

            guard placement.enabled else { continue }

            parsed.append(
                BuiltinGroupConfig(
                    id: key,
                    placement: placement,
                    style: style
                )
            )
        }

        builtinGroups = parsed
    }
}
