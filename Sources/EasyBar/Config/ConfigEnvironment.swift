import Foundation

extension Config {

    /// Returns the config path override from the environment when present.
    func environmentConfigPathOverride() -> String? {
        expandedEnvironmentPath(named: "EASYBAR_CONFIG_PATH")
    }

    /// Applies environment variable overrides after file parsing.
    func applyEnvironmentOverrides() {
        if let widgetsOverride = expandedEnvironmentPath(named: "EASYBAR_WIDGETS_PATH") {
            widgetsPath = widgetsOverride
        }

        if let logEnabled = ProcessInfo.processInfo.environment["EASYBAR_LOG_ENABLED"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !logEnabled.isEmpty {
            logToFile = ["1", "true", "yes", "on"].contains(logEnabled.lowercased())
        }

        if let logFile = expandedEnvironmentPath(named: "EASYBAR_LOG_FILE") {
            logFilePath = logFile
        }
    }

    /// Returns one expanded path-like environment variable when present and non-empty.
    private func expandedEnvironmentPath(named name: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[name]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return NSString(string: value).expandingTildeInPath
    }
}
