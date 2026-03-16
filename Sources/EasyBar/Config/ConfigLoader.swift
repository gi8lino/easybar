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
            applyEnvironmentOverrides()
            Logger.configure(logToFile: logToFile, filePath: logFilePath)
            return
        }

        do {
            let toml = try TOMLTable(string: text)

            try parsePaths(from: toml)
            try parseBar(from: toml)
            try parseSpaces(from: toml)
            try parseSpaceText(from: toml)
            try parseIcons(from: toml)
            try parseColors(from: toml)
            try parseLua(from: toml)
            try parseLogging(from: toml)
            try parseBuiltins(from: toml)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.invalidValue(
                path: "config",
                message: "parse failed: \(error)"
            )
        }

        applyEnvironmentOverrides()
        Logger.configure(logToFile: logToFile, filePath: logFilePath)
    }
}
