import Foundation

/// Central app logger used by Swift and Lua runtime messages.
enum Logger {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    private static let lock = NSLock()
    private static var fileHandle: FileHandle?

    static var debugEnabled: Bool {
        if let override = Config.shared.environmentDebugOverride() {
            return override
        }

        return Config.shared.loggingDebugEnabled
    }

    /// Configures optional mirroring of logs into one file.
    static func configureFileLogging(enabled: Bool, path: String) {
        lock.lock()
        defer { lock.unlock() }

        fileHandle?.closeFile()
        fileHandle = nil

        guard enabled, !path.isEmpty else { return }

        let url = URL(fileURLWithPath: path)
        let directoryURL = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            fileHandle = handle

            let line = formattedLine(
                level: "INFO",
                message: "file logging enabled path=\(url.path)"
            )
            fputs(line + "\n", stdout)
            fflush(stdout)
            try handle.write(contentsOf: Data((line + "\n").utf8))
        } catch {
            let line = formattedLine(
                level: "WARN",
                message: "failed to open log file at \(path): \(error)"
            )
            fputs(line + "\n", stderr)
            fflush(stderr)
        }
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
        writeFile(line)
    }

    /// Writes one formatted log line to stderr.
    private static func writeStderr(level: String, message: String) {
        let line = formattedLine(level: level, message: message)
        fputs(line + "\n", stderr)
        fflush(stderr)
        writeFile(line)
    }

    /// Returns one formatted log line.
    private static func formattedLine(level: String, message: String) -> String {
        "[\(formatter.string(from: Date()))] easybar [\(level)] \(message)"
    }

    private static func writeFile(_ line: String) {
        guard let data = (line + "\n").data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }

        do {
            try fileHandle?.write(contentsOf: data)
        } catch {
            fputs(formattedLine(level: "WARN", message: "failed writing log file: \(error)") + "\n", stderr)
            fflush(stderr)
            fileHandle?.closeFile()
            fileHandle = nil
        }
    }
}
