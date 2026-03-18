import Foundation

/// Routes structured stderr lines from the Lua runtime into the normal logger.
final class LuaLogBridge {

    /// Handles one stderr line from the Lua runtime.
    func handle(_ line: String) {
        let prefix = "EASYBAR_LOG\t"

        guard line.hasPrefix(prefix) else {
            Logger.error("lua stderr: \(line)")
            return
        }

        let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)

        guard parts.count == 4 else {
            Logger.error("lua stderr: \(line)")
            return
        }

        let level = String(parts[1]).uppercased()
        let source = String(parts[2])
        let message = String(parts[3])

        let formatted = "lua[\(source)] \(message)"

        switch level {
        case "DEBUG":
            Logger.debug(formatted)
        case "INFO":
            Logger.info(formatted)
        case "WARN":
            Logger.warn(formatted)
        case "ERROR":
            Logger.error(formatted)
        default:
            Logger.info(formatted)
        }
    }
}
