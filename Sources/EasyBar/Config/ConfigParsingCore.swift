import Foundation
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

        if let colors = bar["colors"]?.table {
            if let value = colors["background"] {
                barBackgroundHex = try requiredString(value, path: "bar.colors.background")
            }

            if let value = colors["border"] {
                barBorderHex = try requiredString(value, path: "bar.colors.border")
            }
        }

        // Backward compatibility.
        if let value = bar["background_color"] {
            barBackgroundHex = try requiredString(value, path: "bar.background_color")
        }

        if let value = bar["border_color"] {
            barBorderHex = try requiredString(value, path: "bar.border_color")
        }
    }

    func parseSpaces(from toml: TOMLTable) throws {
        guard let spaces = toml["spaces"]?.table else { return }

        if let value = spaces["spacing"] {
            builtinSpaces.layout.spacing = Double(try requiredInt(value, path: "spaces.spacing"))
        }

        if let value = spaces["hide_empty"] {
            builtinSpaces.layout.hideEmpty = try requiredBool(value, path: "spaces.hide_empty")
        }

        if let value = spaces["padding_x"] {
            builtinSpaces.layout.paddingX = Double(try requiredInt(value, path: "spaces.padding_x"))
        }

        if let value = spaces["padding_y"] {
            builtinSpaces.layout.paddingY = Double(try requiredInt(value, path: "spaces.padding_y"))
        }

        if let value = spaces["corner_radius"] {
            builtinSpaces.layout.cornerRadius = Double(try requiredInt(value, path: "spaces.corner_radius"))
        }

        if let value = spaces["focused_scale"] {
            builtinSpaces.layout.focusedScale = try requiredNumber(value, path: "spaces.focused_scale")
        }

        if let value = spaces["inactive_opacity"] {
            builtinSpaces.layout.inactiveOpacity = try requiredNumber(value, path: "spaces.inactive_opacity")
        }

        if let value = spaces["max_icons"] {
            builtinSpaces.layout.maxIcons = try requiredInt(value, path: "spaces.max_icons")
        }

        if let value = spaces["show_number"] {
            builtinSpaces.layout.showNumber = try requiredBool(value, path: "spaces.show_number")
        }

        if let value = spaces["show_icons"] {
            builtinSpaces.layout.showIcons = try requiredBool(value, path: "spaces.show_icons")
        }

        if let value = spaces["show_only_focused_label"] {
            builtinSpaces.layout.showOnlyFocusedLabel = try requiredBool(value, path: "spaces.show_only_focused_label")
        }

        if let value = spaces["collapse_inactive"] {
            builtinSpaces.layout.collapseInactive = try requiredBool(value, path: "spaces.collapse_inactive")
        }

        if let value = spaces["collapsed_padding_x"] {
            builtinSpaces.layout.collapsedPaddingX = Double(try requiredInt(value, path: "spaces.collapsed_padding_x"))
        }

        if let value = spaces["collapsed_padding_y"] {
            builtinSpaces.layout.collapsedPaddingY = Double(try requiredInt(value, path: "spaces.collapsed_padding_y"))
        }
    }

    func parseSpaceText(from toml: TOMLTable) throws {
        guard let spaceText = toml["space_text"]?.table else { return }

        if let value = spaceText["size"] {
            builtinSpaces.text.size = Double(try requiredInt(value, path: "space_text.size"))
        }

        if let value = spaceText["weight"] {
            builtinSpaces.text.weight = try requiredString(value, path: "space_text.weight")
        }

        if let value = spaceText["focused_color"] {
            builtinSpaces.text.focusedColorHex = try requiredString(value, path: "space_text.focused_color")
        }

        if let value = spaceText["inactive_color"] {
            builtinSpaces.text.inactiveColorHex = try requiredString(value, path: "space_text.inactive_color")
        }
    }

    func parseIcons(from toml: TOMLTable) throws {
        guard let icons = toml["icons"]?.table else { return }

        if let value = icons["size"] {
            builtinSpaces.icons.size = Double(try requiredInt(value, path: "icons.size"))
        }

        if let value = icons["spacing"] {
            builtinSpaces.icons.spacing = Double(try requiredInt(value, path: "icons.spacing"))
        }

        if let value = icons["corner_radius"] {
            builtinSpaces.icons.cornerRadius = Double(try requiredInt(value, path: "icons.corner_radius"))
        }

        if let value = icons["focused_size"] {
            builtinSpaces.icons.focusedSize = Double(try requiredInt(value, path: "icons.focused_size"))
        }

        if let value = icons["border_width"] {
            builtinSpaces.icons.borderWidth = Double(try requiredInt(value, path: "icons.border_width"))
        }

        if let value = icons["focused_border_width"] {
            builtinSpaces.icons.focusedBorderWidth = Double(try requiredInt(value, path: "icons.focused_border_width"))
        }
    }

    func parseColors(from toml: TOMLTable) throws {
        guard let colors = toml["colors"]?.table else { return }

        if let value = colors["text_color"] {
            textColorHex = try requiredString(value, path: "colors.text_color")
        }

        if let value = colors["space_active_background"] {
            builtinSpaces.colors.activeBackgroundHex = try requiredString(value, path: "colors.space_active_background")
        }

        if let value = colors["space_inactive_background"] {
            builtinSpaces.colors.inactiveBackgroundHex = try requiredString(value, path: "colors.space_inactive_background")
        }

        if let value = colors["space_active_border"] {
            builtinSpaces.colors.activeBorderHex = try requiredString(value, path: "colors.space_active_border")
        }

        if let value = colors["space_inactive_border"] {
            builtinSpaces.colors.inactiveBorderHex = try requiredString(value, path: "colors.space_inactive_border")
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
}
