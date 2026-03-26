import Foundation

extension Config {

    /// Returns the config path override from the environment when present.
    func environmentConfigPathOverride() -> String? {
        expandedEnvironmentPath(named: "EASYBAR_CONFIG_PATH")
    }

    /// Returns the debug logging override from the environment when present.
    func environmentDebugOverride() -> Bool? {
        boolEnvironmentValue(named: "EASYBAR_DEBUG")
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

    /// Returns one boolean environment variable when present and valid.
    private func boolEnvironmentValue(named name: String) -> Bool? {
        guard let value = ProcessInfo.processInfo.environment[name]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        switch value.lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return nil
        }
    }
}
