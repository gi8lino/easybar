import Foundation
import TOMLKit

extension Config {

    func parsePaths(from toml: TOMLTable) throws {
        guard let paths = toml["paths"]?.table else { return }

        guard let value = paths["widgets"] else { return }

        widgetsPath = NSString(
            string: try requiredString(value, path: "paths.widgets")
        ).expandingTildeInPath
    }

    func parseBar(from toml: TOMLTable) throws {
        guard let bar = toml["bar"]?.table else { return }

        if let value = bar["height"] {
            barHeight = CGFloat(try requiredInt(value, path: "bar.height"))
        }

        if let value = bar["padding"] {
            barPadding = CGFloat(try requiredInt(value, path: "bar.padding"))
        }

        guard let colors = bar["colors"]?.table else { return }

        if let value = colors["background"] {
            barBackgroundHex = try requiredString(value, path: "bar.colors.background")
        }

        if let value = colors["border"] {
            barBorderHex = try requiredString(value, path: "bar.colors.border")
        }

        if let value = colors["text"] {
            textColorHex = try requiredString(value, path: "bar.colors.text")
        }

        if let value = colors["focused_app_border"] {
            focusedAppBorderHex = try requiredString(value, path: "bar.colors.focused_app_border")
        }
    }

    func parseLua(from toml: TOMLTable) throws {
        guard let lua = toml["lua"]?.table else { return }
        guard let value = lua["path"] else { return }

        luaPath = try requiredString(value, path: "lua.path")
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
