import Foundation
import SwiftUI
import TOMLKit

extension Config {

    func parsePaths(from toml: TOMLTable) throws {
        if let paths = toml["paths"]?.table,
           let value = paths["widgets"] {
            widgetsPath = NSString(
                string: try requiredString(value, path: "paths.widgets")
            ).expandingTildeInPath
        }
    }

    func parseBar(from toml: TOMLTable) throws {
        guard let bar = toml["bar"]?.table else { return }

        if let value = bar["height"] {
            barHeight = CGFloat(try requiredInt(value, path: "bar.height"))
        }

        if let value = bar["padding"] {
            barPadding = CGFloat(try requiredInt(value, path: "bar.padding"))
        }
    }

    func parseSpaces(from toml: TOMLTable) throws {
        guard let spaces = toml["spaces"]?.table else { return }

        if let value = spaces["spacing"] {
            spaceSpacing = CGFloat(try requiredInt(value, path: "spaces.spacing"))
        }

        if let value = spaces["hide_empty"] {
            hideEmptySpaces = try requiredBool(value, path: "spaces.hide_empty")
        }

        if let value = spaces["padding_x"] {
            spacePaddingX = CGFloat(try requiredInt(value, path: "spaces.padding_x"))
        }

        if let value = spaces["padding_y"] {
            spacePaddingY = CGFloat(try requiredInt(value, path: "spaces.padding_y"))
        }

        if let value = spaces["corner_radius"] {
            spaceCornerRadius = CGFloat(try requiredInt(value, path: "spaces.corner_radius"))
        }

        // Keep fractional scale supported.
        if let value = spaces["focused_scale"] {
            spaceFocusedScale = CGFloat(try requiredNumber(value, path: "spaces.focused_scale"))
        }

        // Keep fractional opacity supported.
        if let value = spaces["inactive_opacity"] {
            spaceInactiveOpacity = try requiredNumber(value, path: "spaces.inactive_opacity")
        }

        if let value = spaces["max_icons"] {
            maxIconsPerSpace = try requiredInt(value, path: "spaces.max_icons")
        }

        if let value = spaces["show_number"] {
            showSpaceNumber = try requiredBool(value, path: "spaces.show_number")
        }

        if let value = spaces["show_icons"] {
            showSpaceIcons = try requiredBool(value, path: "spaces.show_icons")
        }

        if let value = spaces["show_only_focused_label"] {
            showOnlyFocusedLabel = try requiredBool(value, path: "spaces.show_only_focused_label")
        }

        if let value = spaces["collapse_inactive"] {
            collapseInactiveSpaces = try requiredBool(value, path: "spaces.collapse_inactive")
        }

        if let value = spaces["collapsed_padding_x"] {
            collapsedSpacePaddingX = CGFloat(try requiredInt(value, path: "spaces.collapsed_padding_x"))
        }

        if let value = spaces["collapsed_padding_y"] {
            collapsedSpacePaddingY = CGFloat(try requiredInt(value, path: "spaces.collapsed_padding_y"))
        }
    }

    func parseSpaceText(from toml: TOMLTable) throws {
        guard let spaceText = toml["space_text"]?.table else { return }

        if let value = spaceText["size"] {
            spaceTextSize = CGFloat(try requiredInt(value, path: "space_text.size"))
        }

        if let value = spaceText["weight"] {
            spaceTextWeight = try requiredString(value, path: "space_text.weight")
        }

        if let value = spaceText["focused_color"] {
            spaceFocusedTextHex = try requiredString(value, path: "space_text.focused_color")
        }

        if let value = spaceText["inactive_color"] {
            spaceInactiveTextHex = try requiredString(value, path: "space_text.inactive_color")
        }
    }

    func parseIcons(from toml: TOMLTable) throws {
        guard let icons = toml["icons"]?.table else { return }

        if let value = icons["size"] {
            iconSize = CGFloat(try requiredInt(value, path: "icons.size"))
        }

        if let value = icons["spacing"] {
            iconSpacing = CGFloat(try requiredInt(value, path: "icons.spacing"))
        }

        if let value = icons["corner_radius"] {
            iconCornerRadius = CGFloat(try requiredInt(value, path: "icons.corner_radius"))
        }

        if let value = icons["focused_size"] {
            focusedIconSize = CGFloat(try requiredInt(value, path: "icons.focused_size"))
        }

        if let value = icons["border_width"] {
            iconBorderWidth = CGFloat(try requiredInt(value, path: "icons.border_width"))
        }

        if let value = icons["focused_border_width"] {
            focusedIconBorderWidth = CGFloat(try requiredInt(value, path: "icons.focused_border_width"))
        }
    }

    func parseColors(from toml: TOMLTable) throws {
        guard let colors = toml["colors"]?.table else { return }

        if let value = colors["bar_background"] {
            barBackgroundHex = try requiredString(value, path: "colors.bar_background")
        }

        if let value = colors["bar_border"] {
            barBorderHex = try requiredString(value, path: "colors.bar_border")
        }

        if let value = colors["text_color"] {
            textColorHex = try requiredString(value, path: "colors.text_color")
        }

        if let value = colors["space_active_background"] {
            spaceActiveBackgroundHex = try requiredString(value, path: "colors.space_active_background")
        }

        if let value = colors["space_inactive_background"] {
            spaceInactiveBackgroundHex = try requiredString(value, path: "colors.space_inactive_background")
        }

        if let value = colors["space_active_border"] {
            spaceActiveBorderHex = try requiredString(value, path: "colors.space_active_border")
        }

        if let value = colors["space_inactive_border"] {
            spaceInactiveBorderHex = try requiredString(value, path: "colors.space_inactive_border")
        }

        if let value = colors["focused_app_border"] {
            focusedAppBorderHex = try requiredString(value, path: "colors.focused_app_border")
        }
    }

    func parseLua(from toml: TOMLTable) throws {
        guard let lua = toml["lua"]?.table else { return }

        if let value = lua["path"] {
            luaPath = try requiredString(value, path: "lua.path")
        }
    }

    func parseLogging(from toml: TOMLTable) throws {
        guard let logging = toml["logging"]?.table else { return }

        if let value = logging["enabled"] {
            logToFile = try requiredBool(value, path: "logging.enabled")
        }

        if let value = logging["file"] {
            logFilePath = NSString(
                string: try requiredString(value, path: "logging.file")
            ).expandingTildeInPath
        }
    }

    // MARK: - Type helpers

    // Internal so builtins parsing can reuse them.
    func requiredString(_ value: any TOMLValueConvertible, path: String) throws -> String {
        if let string = value.string {
            return string
        }

        throw ConfigError.invalidType(
            path: path,
            expected: "string",
            actual: describe(value)
        )
    }

    func requiredBool(_ value: any TOMLValueConvertible, path: String) throws -> Bool {
        if let bool = value.bool {
            return bool
        }

        throw ConfigError.invalidType(
            path: path,
            expected: "bool",
            actual: describe(value)
        )
    }

    func requiredInt(_ value: any TOMLValueConvertible, path: String) throws -> Int {
        if let int = value.int {
            return int
        }

        throw ConfigError.invalidType(
            path: path,
            expected: "integer",
            actual: describe(value)
        )
    }

    func requiredNumber(_ value: any TOMLValueConvertible, path: String) throws -> Double {
        if let double = value.double {
            return double
        }

        if let int = value.int {
            return Double(int)
        }

        throw ConfigError.invalidType(
            path: path,
            expected: "number",
            actual: describe(value)
        )
    }

    func describe(_ value: any TOMLValueConvertible) -> String {
        if let string = value.string {
            return "string(\(string.debugDescription))"
        }

        if let int = value.int {
            return "integer(\(int))"
        }

        if let double = value.double {
            return "number(\(double))"
        }

        if let bool = value.bool {
            return "bool(\(bool))"
        }

        if value.array != nil {
            return "array"
        }

        if value.table != nil {
            return "table"
        }

        return "unknown"
    }
}
