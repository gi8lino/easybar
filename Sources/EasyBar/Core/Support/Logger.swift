import Foundation

/// Central app logger used by Swift and Lua runtime messages.
enum Logger {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private static let queue = DispatchQueue(label: "easybar.logger")
    private static var fileHandle: FileHandle?
    private static var currentLogPath: String?

    static var debugEnabled: Bool {
        ProcessInfo.processInfo.environment["EASYBAR_DEBUG"] == "1"
    }

    /// Configures optional file logging.
    static func configure(logToFile: Bool, filePath: String) {
        queue.sync {
            closeFileHandle()

            guard logToFile else { return }

            let expandedPath = NSString(string: filePath).expandingTildeInPath
            let directory = URL(fileURLWithPath: expandedPath).deletingLastPathComponent()

            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )

                if !FileManager.default.fileExists(atPath: expandedPath) {
                    FileManager.default.createFile(atPath: expandedPath, contents: nil)
                }

                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: expandedPath))
                try handle.seekToEnd()

                fileHandle = handle
                currentLogPath = expandedPath
            } catch {
                fileHandle = nil
                currentLogPath = nil
                print("[\(formatter.string(from: Date()))] easybar [WARN] failed to open log file \(expandedPath): \(error)")
            }
        }
    }

    /// Writes one debug message when debug logging is enabled.
    static func debug(_ msg: String) {
        guard debugEnabled else { return }
        write(level: "DEBUG", message: msg)
    }

    /// Writes one info message.
    static func info(_ msg: String) {
        write(level: "INFO", message: msg)
    }

    /// Writes one warning message.
    static func warn(_ msg: String) {
        write(level: "WARN", message: msg)
    }

    /// Writes one error message.
    static func error(_ msg: String) {
        write(level: "ERROR", message: msg)
    }

    /// Formats and writes one log line to console and optional file.
    private static func write(level: String, message: String) {
        let line = "[\(formatter.string(from: Date()))] easybar [\(level)] \(message)"
        print(line)

        queue.async {
            guard let fileHandle else { return }
            guard let data = (line + "\n").data(using: .utf8) else { return }

            do {
                try fileHandle.write(contentsOf: data)
            } catch {
                print("[\(formatter.string(from: Date()))] easybar [WARN] failed writing log file \(currentLogPath ?? ""): \(error)")
            }
        }
    }

    /// Closes the currently open log file handle.
    private static func closeFileHandle() {
        try? fileHandle?.close()
        fileHandle = nil
        currentLogPath = nil
    }
}
