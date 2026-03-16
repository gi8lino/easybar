import Foundation

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

    // Called after config is loaded or reloaded.
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
                // Fall back to stdout only.
                fileHandle = nil
                currentLogPath = nil
                print("[\(formatter.string(from: Date()))] easybar: failed to open log file \(expandedPath): \(error)")
            }
        }
    }

    static func debug(_ msg: String) {
        guard debugEnabled else { return }
        write(msg)
    }

    static func info(_ msg: String) {
        write(msg)
    }

    private static func write(_ msg: String) {
        let line = "[\(formatter.string(from: Date()))] easybar: \(msg)"
        print(line)

        queue.async {
            guard let fileHandle else { return }
            guard let data = (line + "\n").data(using: .utf8) else { return }

            do {
                try fileHandle.write(contentsOf: data)
            } catch {
                print("[\(formatter.string(from: Date()))] easybar: failed writing log file \(currentLogPath ?? ""): \(error)")
            }
        }
    }

    private static func closeFileHandle() {
        try? fileHandle?.close()
        fileHandle = nil
        currentLogPath = nil
    }
}
