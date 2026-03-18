import Foundation

/// Handles stdin/stdout/stderr transport for the Lua runtime process.
final class LuaTransport {

    private let writeQueue = DispatchQueue(label: "easybar.lua.write")
    private let logBridge = LuaLogBridge()

    private(set) var inputPipe: Pipe?
    private(set) var outputPipe: Pipe?
    private(set) var errorPipe: Pipe?

    /// Attaches the transport to the given process pipes.
    func attach(input: Pipe, output: Pipe, error: Pipe) {
        inputPipe = input
        outputPipe = output
        errorPipe = error
    }

    /// Installs stdout and stderr readability handlers.
    func startReading() {
        installOutputReadabilityHandler()
        installErrorReadabilityHandler()
    }

    /// Stops all readability handlers and closes pipes.
    func shutdown() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        try? inputPipe?.fileHandleForWriting.close()
        try? outputPipe?.fileHandleForReading.close()
        try? errorPipe?.fileHandleForReading.close()

        inputPipe = nil
        outputPipe = nil
        errorPipe = nil
    }

    /// Sends one encoded event line to the Lua runtime stdin.
    func send(_ string: String) {
        guard let pipe = inputPipe else {
            Logger.debug("cannot send event, lua stdin not available")
            return
        }

        writeQueue.async {
            guard let data = (string + "\n").data(using: .utf8) else { return }

            do {
                try pipe.fileHandleForWriting.write(contentsOf: data)
                Logger.debug("sent to lua stdin: \(string)")
            } catch {
                Logger.error("failed writing to lua stdin: \(error)")
            }
        }
    }

    /// Installs the stdout handler used for structured JSON widget updates.
    private func installOutputReadabilityHandler() {
        guard let pipe = outputPipe else { return }

        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            buffer.append(data)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(...newlineIndex)

                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !line.isEmpty
                else {
                    continue
                }

                Logger.debug("lua stdout raw: \(line)")

                NotificationCenter.default.post(
                    name: .easyBarLuaStdout,
                    object: line
                )
            }
        }
    }

    /// Installs the stderr handler used for Lua/widget logs and runtime failures.
    private func installErrorReadabilityHandler() {
        guard let pipe = errorPipe else { return }

        var buffer = Data()

        pipe.fileHandleForReading.readabilityHandler = { [logBridge] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            buffer.append(data)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(...newlineIndex)

                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !line.isEmpty
                else {
                    continue
                }

                logBridge.handle(line)
            }
        }
    }
}

extension Notification.Name {
    static let easyBarLuaStdout = Notification.Name("easybar.lua.stdout")
}
