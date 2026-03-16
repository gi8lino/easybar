import Foundation

extension Config {

    /// Applies environment variable overrides after file parsing.
    func applyEnvironmentOverrides() {
        if let widgetsOverride = ProcessInfo.processInfo.environment["EASYBAR_WIDGETS_PATH"],
           !widgetsOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            widgetsPath = NSString(string: widgetsOverride).expandingTildeInPath
        }

        if let logEnabled = ProcessInfo.processInfo.environment["EASYBAR_LOG_ENABLED"] {
            logToFile = ["1", "true", "yes", "on"].contains(logEnabled.lowercased())
        }

        if let logFile = ProcessInfo.processInfo.environment["EASYBAR_LOG_FILE"],
           !logFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logFilePath = NSString(string: logFile).expandingTildeInPath
        }
    }
}
