import Foundation

/// Routes structured stderr lines from the Lua runtime into the normal logger.
final class LuaLogBridge {

    private let prefix = "EASYBAR_LOG\t"

    /// Handles one stderr line from the Lua runtime.
    func handle(_ line: String) {
        guard line.hasPrefix(prefix) else {
            logRawStderr(line)
            return
        }

        let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)

        guard parts.count == 4 else {
            logRawStderr(line)
            return
        }

        let level = String(parts[1]).uppercased()
        let source = String(parts[2])
        let message = String(parts[3])

        let formatted = "lua[\(source)] \(message)"

        logFormatted(level: level, message: formatted)
    }

    /// Logs one raw stderr line that does not follow the structured format.
    private func logRawStderr(_ line: String) {
        Logger.error("lua stderr: \(line)")
    }

    /// Logs one structured Lua message at the requested level.
    private func logFormatted(level: String, message: String) {
        switch level {
        case "DEBUG":
            Logger.debug(message)
        case "INFO":
            Logger.info(message)
        case "WARN":
            Logger.warn(message)
        case "ERROR":
            Logger.error(message)
        default:
            Logger.info(message)
        }
    }
}
