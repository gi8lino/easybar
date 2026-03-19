import Foundation

/// Central app logger used by Swift and Lua runtime messages.
enum Logger {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static var debugEnabled: Bool {
        Config.shared.environmentDebugEnabled()
    }

    /// Writes one debug message when debug logging is enabled.
    static func debug(_ msg: String) {
        guard debugEnabled else { return }
        writeStdout(level: "DEBUG", message: msg)
    }

    /// Writes one info message.
    static func info(_ msg: String) {
        writeStdout(level: "INFO", message: msg)
    }

    /// Writes one warning message.
    static func warn(_ msg: String) {
        writeStderr(level: "WARN", message: msg)
    }

    /// Writes one error message.
    static func error(_ msg: String) {
        writeStderr(level: "ERROR", message: msg)
    }

    /// Writes one formatted log line to stdout.
    private static func writeStdout(level: String, message: String) {
        let line = formattedLine(level: level, message: message)
        fputs(line + "\n", stdout)
        fflush(stdout)
    }

    /// Writes one formatted log line to stderr.
    private static func writeStderr(level: String, message: String) {
        let line = formattedLine(level: level, message: message)
        fputs(line + "\n", stderr)
        fflush(stderr)
    }

    /// Returns one formatted log line.
    private static func formattedLine(level: String, message: String) -> String {
        "[\(formatter.string(from: Date()))] easybar [\(level)] \(message)"
    }
}
