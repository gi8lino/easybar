import Darwin
import Foundation
import EasyBarShared

enum AgentLogger {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    private static let lock = NSLock()

    static var debugEnabled: Bool {
        defaultDebugLoggingEnabled()
    }

    static func debug(_ message: String) {
        guard debugEnabled else { return }
        write(level: "DEBUG", message: message)
    }

    static func info(_ message: String) {
        write(level: "INFO", message: message)
    }

    static func warn(_ message: String) {
        write(level: "WARN", message: message, stderr: true)
    }

    static func error(_ message: String) {
        write(level: "ERROR", message: message, stderr: true)
    }

    private static func write(level: String, message: String, stderr: Bool = false) {
        let line = "[\(formatter.string(from: Date()))] easybar-calendar-agent [\(level)] \(message)\n"

        lock.lock()
        defer { lock.unlock() }

        if stderr {
            fputs(line, Darwin.stderr)
            fflush(Darwin.stderr)
        } else {
            fputs(line, Darwin.stdout)
            fflush(Darwin.stdout)
        }
    }
}
