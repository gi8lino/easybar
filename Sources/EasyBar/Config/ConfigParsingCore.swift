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
    }

    /// Parses bar-level settings.
    func parseBar(from toml: TOMLTable) throws {
        guard let bar = toml["bar"]?.table else { return }

        if let value = bar["height"] {
            barHeight = CGFloat(try requiredInt(value, path: "bar.height"))
        }

        if let value = bar["padding_x"] {
            barPaddingX = CGFloat(try requiredInt(value, path: "bar.padding_x"))
        }

        if let value = bar["extend_behind_notch"] {
            barExtendBehindNotch = try requiredBool(
                value,
                path: "bar.extend_behind_notch"
            )
        }

        guard let colors = bar["colors"]?.table else { return }

        if let value = colors["background"] {
            barBackgroundHex = try requiredString(value, path: "bar.colors.background")
        }

        if let value = colors["border"] {
            barBorderHex = try requiredString(value, path: "bar.colors.border")
        }
    }
}
