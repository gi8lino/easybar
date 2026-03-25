import Foundation

enum AgentLogger {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func info(_ message: String) {
        write(level: "INFO", message: message, stream: stdout)
    }

    static func warn(_ message: String) {
        write(level: "WARN", message: message, stream: stderr)
    }

    static func error(_ message: String) {
        write(level: "ERROR", message: message, stream: stderr)
    }

    private static func write(level: String, message: String, stream: UnsafeMutablePointer<FILE>?) {
        fputs("[\(formatter.string(from: Date()))] easybar-network-agent [\(level)] \(message)\n", stream)
        fflush(stream)
    }
}
