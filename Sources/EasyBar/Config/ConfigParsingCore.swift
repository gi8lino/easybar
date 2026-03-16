import Foundation
import TOMLKit

extension Config {

    /// Parses app-level settings.
    func parseApp(from toml: TOMLTable) throws {
        guard let app = toml["app"]?.table else { return }

        if let value = app["widgets_dir"] {
            widgetsPath = NSString(
                string: try requiredString(value, path: "app.widgets_dir")
            ).expandingTildeInPath
        }

        if let value = app["lua_path"] {
            luaPath = try requiredString(value, path: "app.lua_path")
        }

        if let value = app["watch_config"] {
            watchConfigFile = try requiredBool(value, path: "app.watch_config")
        }

        guard let logging = app["logging"]?.table else { return }

        if let value = logging["enabled"] {
            logToFile = try requiredBool(value, path: "app.logging.enabled")
        }

        if let value = logging["file"] {
            logFilePath = NSString(
                string: try requiredString(value, path: "app.logging.file")
            ).expandingTildeInPath
        }
    }

    /// Parses bar-level settings.
    func parseBar(from toml: TOMLTable) throws {
        guard let bar = toml["bar"]?.table else { return }

        if let value = bar["height"] {
            barHeight = CGFloat(try requiredInt(value, path: "bar.height"))
        }

        if let value = bar["padding"] {
            barPadding = CGFloat(try requiredInt(value, path: "bar.padding"))
        }

        if let value = bar["padding_y"] {
            barPaddingY = CGFloat(try requiredInt(value, path: "bar.padding_y"))
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
}
