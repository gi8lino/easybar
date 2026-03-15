import Foundation

enum Logger {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static var debugEnabled: Bool {
        ProcessInfo.processInfo.environment["EASYBAR_DEBUG"] == "1"
    }

    static func debug(_ msg: String) {
        guard debugEnabled else { return }
        print("[\(formatter.string(from: Date()))] easybar: \(msg)")
    }

    static func info(_ msg: String) {
        print("[\(formatter.string(from: Date()))] easybar: \(msg)")
    }
}
