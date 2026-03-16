import Foundation
import TOMLKit

extension Config {

    /// Loads configuration from disk.
    func load() {
        let resolvedConfigPath = configPath

        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedConfigPath)),
            let text = String(data: data, encoding: .utf8)
        else {
            Logger.info("using default configuration from \(resolvedConfigPath)")
            applyEnvironmentOverrides()
            return
        }

        do {
            let toml = try TOMLTable(string: text)

            parsePaths(from: toml)
            parseBar(from: toml)
            parseSpaces(from: toml)
            parseSpaceText(from: toml)
            parseIcons(from: toml)
            parseColors(from: toml)
            parseLua(from: toml)
            parseBuiltins(from: toml)
        } catch {
            Logger.info("config parse error: \(error)")
        }

        applyEnvironmentOverrides()
    }

    /// Applies environment variable overrides after config loading.
    func applyEnvironmentOverrides() {
        if let widgetsOverride = ProcessInfo.processInfo.environment["EASYBAR_WIDGETS_PATH"],
           !widgetsOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            widgetsPath = NSString(string: widgetsOverride).expandingTildeInPath
        }
    }
}
