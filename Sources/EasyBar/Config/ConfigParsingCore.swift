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

    /// Parses logging settings.
    func parseLogging(from toml: TOMLTable) throws {
        guard let logging = toml["logging"]?.table else { return }

        if let value = logging["enabled"] {
            loggingEnabled = try requiredBool(value, path: "logging.enabled")
        }

        if let value = logging["path"] {
            loggingPath = NSString(
                string: try requiredString(value, path: "logging.path")
            ).expandingTildeInPath
        }
    }

    /// Parses agent settings.
    func parseAgents(from toml: TOMLTable) throws {
        guard let agents = toml["agents"]?.table else { return }

        if let calendar = agents["calendar"]?.table {
            if let value = calendar["enabled"] {
                calendarAgentEnabled = try requiredBool(value, path: "agents.calendar.enabled")
            }

            if let value = calendar["socket_path"] {
                calendarAgentSocketPath = NSString(
                    string: try requiredString(value, path: "agents.calendar.socket_path")
                ).expandingTildeInPath
            }
        }

        if let network = agents["network"]?.table {
            if let value = network["enabled"] {
                networkAgentEnabled = try requiredBool(value, path: "agents.network.enabled")
            }

            if let value = network["socket_path"] {
                networkAgentSocketPath = NSString(
                    string: try requiredString(value, path: "agents.network.socket_path")
                ).expandingTildeInPath
            }
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
