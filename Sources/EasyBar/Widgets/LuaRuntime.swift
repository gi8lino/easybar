import Foundation

private var easyBarLuaProcessGroupPID: pid_t = 0

private func easyBarTerminateLuaProcessGroup() {
    let pid = easyBarLuaProcessGroupPID
    guard pid > 0 else { return }

    kill(-pid, SIGTERM)
    usleep(150_000)
    kill(-pid, SIGKILL)

    easyBarLuaProcessGroupPID = 0
}

private func easyBarSignalHandler(_ signal: Int32) {
    easyBarTerminateLuaProcessGroup()
    Darwin.signal(signal, SIG_DFL)
    Darwin.raise(signal)
}

final class LuaRuntime {

    static let shared = LuaRuntime()

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    private let writeQueue = DispatchQueue(label: "easybar.lua.write")
    private var signalHandlersInstalled = false

    private init() {}

    func start() {
        guard process == nil else {
            Logger.debug("lua runtime already started")
            return
        }

        installSignalHandlersIfNeeded()

        guard let runtime = Bundle.module.url(forResource: "runtime", withExtension: "lua") else {
            Logger.info("runtime.lua not found")
            return
        }

        Logger.debug("starting lua runtime")
        Logger.debug("lua binary: \(Config.shared.luaPath)")
        Logger.debug("runtime script: \(runtime.path)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Config.shared.luaPath)
        process.arguments = [runtime.path]

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()

        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        process.terminationHandler = { process in
            Logger.info("lua runtime terminated status=\(process.terminationStatus)")

            if easyBarLuaProcessGroupPID == process.processIdentifier {
                easyBarLuaProcessGroupPID = 0
            }
        }

        do {
            try process.run()
        } catch {
            Logger.info("failed to start lua runtime: \(error)")
            return
        }

        let pid = process.processIdentifier
        _ = setpgid(pid, pid)
        easyBarLuaProcessGroupPID = pid

        self.process = process
        self.inputPipe = inPipe
        self.outputPipe = outPipe
        self.errorPipe = errPipe

        Logger.debug("lua runtime started pid=\(pid)")

        installOutputReadabilityHandler()
        installErrorReadabilityHandler()
    }

    func shutdown() {
        guard let process else { return }

        Logger.debug("shutting down lua runtime pid=\(process.processIdentifier)")

        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil

        try? inputPipe?.fileHandleForWriting.close()

        easyBarTerminateLuaProcessGroup()

        try? outputPipe?.fileHandleForReading.close()
        try? errorPipe?.fileHandleForReading.close()

        self.process = nil
        self.inputPipe = nil
        self.outputPipe = nil
        self.errorPipe = nil
    }

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
                Logger.debug("failed writing to lua stdin: \(error)")
            }
        }
    }

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

    private func installErrorReadabilityHandler() {
        guard let pipe = errorPipe else { return }

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

                Logger.debug("lua stderr: \(line)")
            }
        }
    }

    private func installSignalHandlersIfNeeded() {
        guard !signalHandlersInstalled else { return }
        signalHandlersInstalled = true

        Darwin.signal(SIGINT, easyBarSignalHandler)
        Darwin.signal(SIGTERM, easyBarSignalHandler)
        Darwin.signal(SIGHUP, easyBarSignalHandler)
        Darwin.signal(SIGABRT, easyBarSignalHandler)
        Darwin.signal(SIGQUIT, easyBarSignalHandler)
    }
}

extension Notification.Name {
    static let easyBarLuaStdout = Notification.Name("easybar.lua.stdout")
}
