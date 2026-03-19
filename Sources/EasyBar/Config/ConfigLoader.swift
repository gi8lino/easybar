import Foundation
import TOMLKit

extension Config {

    /// Loads configuration from disk.
    func load() throws {
        let resolvedConfigPath = configPath

        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedConfigPath)),
            let text = String(data: data, encoding: .utf8)
        else {
            Logger.info("using default configuration from \(resolvedConfigPath)")
            return
        }

        do {
            let toml = try TOMLTable(string: text)

            // Core top-level sections.
            try parseApp(from: toml)
            try parseBar(from: toml)

            // Built-in widgets.
            try parseBuiltins(from: toml)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.invalidValue(
                path: "config",
                message: "parse failed: \(error)"
            )
        }
    }
}
